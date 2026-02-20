-- Migration: Update Menu Options Structure for Reusability
-- Description: Make menu_option_groups reusable via menu_item_option_links table
-- Date: 2024-01-30

-- Create menu_item_option_links table for linking menu items to option groups
CREATE TABLE IF NOT EXISTS menu_item_option_links (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    option_group_id UUID NOT NULL REFERENCES menu_option_groups(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique combination of menu_item and option_group
    UNIQUE(menu_item_id, option_group_id)
);

-- Enable Row Level Security (RLS)
ALTER TABLE menu_item_option_links ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_menu_item_option_links_menu_item_id ON menu_item_option_links(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_option_links_option_group_id ON menu_item_option_links(option_group_id);
CREATE INDEX IF NOT EXISTS idx_menu_item_option_links_sort_order ON menu_item_option_links(menu_item_id, sort_order);

-- RLS Policies for menu_item_option_links
-- Policy: Public can view links
CREATE POLICY "Public can view menu item option links" ON menu_item_option_links
    FOR SELECT USING (true);

-- Policy: Authenticated users can manage links
CREATE POLICY "Authenticated users can manage menu item option links" ON menu_item_option_links
    FOR ALL USING (auth.role() = 'authenticated');

-- Remove menu_item_id from menu_option_groups to make them reusable
ALTER TABLE menu_option_groups DROP COLUMN IF EXISTS menu_item_id;

-- Add merchant_id to menu_option_groups for ownership
ALTER TABLE menu_option_groups ADD COLUMN IF NOT EXISTS merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE;

-- Create updated_at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updated_at on links table
CREATE TRIGGER update_menu_item_option_links_updated_at 
    BEFORE UPDATE ON menu_item_option_links 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Update existing menu_option_groups to have merchant_id (if they exist)
DO $$
BEGIN
    -- If there are existing option groups, try to assign merchant_id
    -- This assumes we can derive merchant_id from associated menu items
    UPDATE menu_option_groups mog
    SET merchant_id = mi.merchant_id
    FROM menu_items mi
    JOIN menu_item_option_links miol ON mi.id = miol.menu_item_id
    WHERE mog.id = miol.option_group_id
    AND mog.merchant_id IS NULL;
    
    -- If no links exist yet, try to get merchant_id from any menu item
    -- This is a fallback for migration purposes
    IF NOT FOUND THEN
        UPDATE menu_option_groups mog
        SET merchant_id = (SELECT merchant_id FROM menu_items LIMIT 1)
        WHERE mog.merchant_id IS NULL;
    END IF;
END $$;

-- Migrate existing direct relationships to links (if any)
DO $$
BEGIN
    -- Insert links for existing menu_item_id relationships (if they existed before this migration)
    -- This handles migration from the old schema
    INSERT INTO menu_item_option_links (menu_item_id, option_group_id, sort_order)
    SELECT 
        mi.id as menu_item_id,
        mog.id as option_group_id,
        0 as sort_order
    FROM menu_items mi
    CROSS JOIN menu_option_groups mog
    WHERE mog.merchant_id = mi.merchant_id
    ON CONFLICT (menu_item_id, option_group_id) DO NOTHING;
END $$;

-- Add helpful comments
COMMENT ON TABLE menu_item_option_links IS 'Links menu items to reusable option groups with sort order';
COMMENT ON COLUMN menu_item_option_links.sort_order IS 'Display order for option groups within a menu item';

COMMENT ON TABLE menu_option_groups IS 'Reusable groups of options for menu items (e.g., Spiciness Level, Add-ons)';
COMMENT ON COLUMN menu_option_groups.merchant_id IS 'Merchant who owns this option group';

-- Update the view to work with the new structure
DROP VIEW IF EXISTS menu_items_with_options;

CREATE OR REPLACE VIEW menu_items_with_options AS
SELECT 
    mi.id as menu_item_id,
    mi.name as menu_item_name,
    mi.price as base_price,
    miol.sort_order,
    mog.id as group_id,
    mog.name as group_name,
    mog.min_selection,
    mog.max_selection,
    mo.id as option_id,
    mo.name as option_name,
    mo.price as option_price,
    mo.is_available as option_available
FROM menu_items mi
LEFT JOIN menu_item_option_links miol ON mi.id = miol.menu_item_id
LEFT JOIN menu_option_groups mog ON miol.option_group_id = mog.id
LEFT JOIN menu_options mo ON mog.id = mo.group_id
ORDER BY mi.name, miol.sort_order, mog.name, mo.name;

COMMENT ON VIEW menu_items_with_options IS 'Convenient view for querying menu items with all their option groups and individual options using the new reusable structure';

-- Update the calculate_menu_item_price function to work with the new structure
CREATE OR REPLACE FUNCTION calculate_menu_item_price(
    p_menu_item_id UUID,
    p_selected_option_ids UUID[] DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    base_price INTEGER;
    options_price INTEGER := 0;
BEGIN
    -- Get base price of menu item
    SELECT price INTO base_price
    FROM menu_items
    WHERE id = p_menu_item_id;
    
    -- If no options selected, return base price
    IF p_selected_option_ids IS NULL OR array_length(p_selected_option_ids, 1) IS NULL THEN
        RETURN COALESCE(base_price, 0);
    END IF;
    
    -- Sum up prices of selected options (only from groups linked to this menu item)
    SELECT COALESCE(SUM(mo.price), 0) INTO options_price
    FROM menu_options mo
    JOIN menu_option_groups mog ON mo.group_id = mog.id
    JOIN menu_item_option_links miol ON mog.id = miol.option_group_id
    WHERE mo.id = ANY(p_selected_option_ids)
    AND miol.menu_item_id = p_menu_item_id
    AND mo.is_available = true;
    
    -- Return total price
    RETURN COALESCE(base_price, 0) + options_price;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_menu_item_price IS 'Calculate total price of menu item including selected options using the new reusable structure';

-- Update the validate_option_selections function to work with the new structure
CREATE OR REPLACE FUNCTION validate_option_selections(
    p_menu_item_id UUID,
    p_selected_option_ids UUID[] DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    group_record RECORD;
    selected_count INTEGER;
BEGIN
    -- If no options selected, validation passes
    IF p_selected_option_ids IS NULL OR array_length(p_selected_option_ids, 1) IS NULL THEN
        RETURN true;
    END IF;
    
    -- Check each option group linked to this menu item
    FOR group_record IN 
        SELECT mog.id, mog.min_selection, mog.max_selection
        FROM menu_option_groups mog
        JOIN menu_item_option_links miol ON mog.id = miol.option_group_id
        WHERE miol.menu_item_id = p_menu_item_id
        ORDER BY miol.sort_order
    LOOP
        -- Count how many options from this group are selected
        SELECT COUNT(*) INTO selected_count
        FROM menu_options mo
        WHERE mo.group_id = group_record.id
        AND mo.id = ANY(p_selected_option_ids)
        AND mo.is_available = true;
        
        -- Validate min and max selection constraints
        IF selected_count < group_record.min_selection THEN
            RAISE EXCEPTION 'Minimum selection not met for group %', group_record.id;
            RETURN false;
        END IF;
        
        IF selected_count > group_record.max_selection THEN
            RAISE EXCEPTION 'Maximum selection exceeded for group %', group_record.id;
            RETURN false;
        END IF;
    END LOOP;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_option_selections IS 'Validate that selected options meet min/max constraints for each group using the new reusable structure';

-- Create a function to get all option groups for a merchant
CREATE OR REPLACE FUNCTION get_merchant_option_groups(p_merchant_id UUID)
RETURNS TABLE (
    group_id UUID,
    group_name TEXT,
    min_selection INTEGER,
    max_selection INTEGER,
    option_id UUID,
    option_name TEXT,
    option_price INTEGER,
    option_available BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mog.id as group_id,
        mog.name as group_name,
        mog.min_selection,
        mog.max_selection,
        mo.id as option_id,
        mo.name as option_name,
        mo.price as option_price,
        mo.is_available as option_available
    FROM menu_option_groups mog
    LEFT JOIN menu_options mo ON mog.id = mo.group_id
    WHERE mog.merchant_id = p_merchant_id
    ORDER BY mog.name, mo.name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_merchant_option_groups IS 'Get all option groups and their options for a specific merchant';

-- Create a function to link an option group to multiple menu items
CREATE OR REPLACE FUNCTION link_option_group_to_menu_items(
    p_option_group_id UUID,
    p_menu_item_ids UUID[]
)
RETURNS INTEGER AS $$
DECLARE
    link_count INTEGER := 0;
    menu_item_id UUID;
BEGIN
    FOREACH menu_item_id IN ARRAY p_menu_item_ids
    LOOP
        INSERT INTO menu_item_option_links (menu_item_id, option_group_id, sort_order)
        VALUES (menu_item_id, p_option_group_id, link_count)
        ON CONFLICT (menu_item_id, option_group_id) DO NOTHING;
        
        GET DIAGNOSTICS link_count = ROW_COUNT;
    END LOOP;
    
    RETURN link_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION link_option_group_to_menu_items IS 'Link an option group to multiple menu items at once';

-- Output summary
SELECT 
    'Menu Options Structure Migration Completed' as status,
    NOW() as completed_at,
    (SELECT COUNT(*) FROM menu_option_groups) as total_option_groups,
    (SELECT COUNT(*) FROM menu_options) as total_options,
    (SELECT COUNT(*) FROM menu_item_option_links) as total_links;
