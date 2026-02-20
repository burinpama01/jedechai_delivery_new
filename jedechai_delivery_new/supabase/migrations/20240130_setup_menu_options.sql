-- Migration: Setup Menu Options for Food Delivery
-- Description: Add menu option groups and individual options for menu items
-- Date: 2024-01-30

-- Create menu_option_groups table
CREATE TABLE IF NOT EXISTS menu_option_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    min_selection INTEGER DEFAULT 0 CHECK (min_selection >= 0),
    max_selection INTEGER DEFAULT 1 CHECK (max_selection >= 1),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create menu_options table
CREATE TABLE IF NOT EXISTS menu_options (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES menu_option_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price INTEGER DEFAULT 0 CHECK (price >= 0),
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE menu_option_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_options ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_menu_option_groups_menu_item_id ON menu_option_groups(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_options_group_id ON menu_options(group_id);

-- RLS Policies for menu_option_groups
-- Policy: Public can view option groups
CREATE POLICY "Public can view menu option groups" ON menu_option_groups
    FOR SELECT USING (true);

-- Policy: Authenticated users can manage option groups
CREATE POLICY "Authenticated users can manage menu option groups" ON menu_option_groups
    FOR ALL USING (auth.role() = 'authenticated');

-- RLS Policies for menu_options
-- Policy: Public can view menu options
CREATE POLICY "Public can view menu options" ON menu_options
    FOR SELECT USING (true);

-- Policy: Authenticated users can manage menu options
CREATE POLICY "Authenticated users can manage menu options" ON menu_options
    FOR ALL USING (auth.role() = 'authenticated');

-- Create updated_at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_menu_option_groups_updated_at 
    BEFORE UPDATE ON menu_option_groups 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_options_updated_at 
    BEFORE UPDATE ON menu_options 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert mock data for testing
-- First, let's check if we have any menu items and use one for testing
-- If no menu items exist, we'll create a placeholder one

DO $$
DECLARE
    test_menu_item UUID;
BEGIN
    -- Try to find an existing menu item
    SELECT id INTO test_menu_item 
    FROM menu_items 
    LIMIT 1;
    
    -- If no menu item found, create a placeholder
    IF test_menu_item IS NULL THEN
        INSERT INTO menu_items (id, merchant_id, name, description, price, category, is_available)
        VALUES (
            gen_random_uuid(),
            (SELECT id FROM merchants LIMIT 1),
            'Test Pad Thai',
            'Traditional Thai stir-fried noodles',
            120,
            'Main Course',
            true
        )
        RETURNING id INTO test_menu_item;
    END IF;
    
    -- Insert Option Group 1: Level of Spiciness (Required, Single Select)
    INSERT INTO menu_option_groups (menu_item_id, name, min_selection, max_selection)
    VALUES (
        test_menu_item,
        'Level of Spiciness',
        1, -- Required
        1  -- Single select
    )
    RETURNING id INTO test_menu_item;
    
    -- Insert Options for Spiciness Group
    INSERT INTO menu_options (group_id, name, price, is_available)
    VALUES 
        (test_menu_item, 'Not Spicy', 0, true),
        (test_menu_item, 'Medium Spicy', 0, true),
        (test_menu_item, 'Very Spicy', 0, true);
    
    -- Insert Option Group 2: Add-ons (Optional, Multi Select)
    INSERT INTO menu_option_groups (menu_item_id, name, min_selection, max_selection)
    VALUES (
        (SELECT id FROM menu_items LIMIT 1),
        'Add-ons',
        0, -- Optional
        5  -- Multi select (up to 5 items)
    )
    RETURNING id INTO test_menu_item;
    
    -- Insert Options for Add-ons Group
    INSERT INTO menu_options (group_id, name, price, is_available)
    VALUES 
        (test_menu_item, 'Extra Pork (+20฿)', 20, true),
        (test_menu_item, 'Fried Egg (+10฿)', 10, true),
        (test_menu_item, 'Extra Noodles (+15฿)', 15, true),
        (test_menu_item, 'Spring Roll (+25฿)', 25, true),
        (test_menu_item, 'Extra Vegetables (+8฿)', 8, true);
END $$;

-- Add helpful comments
COMMENT ON TABLE menu_option_groups IS 'Groups of options for menu items (e.g., Spiciness Level, Add-ons)';
COMMENT ON COLUMN menu_option_groups.min_selection IS 'Minimum number of options user must select (0 = optional)';
COMMENT ON COLUMN menu_option_groups.max_selection IS 'Maximum number of options user can select (1 = radio, >1 = checkbox)';

COMMENT ON TABLE menu_options IS 'Individual options within option groups (e.g., Not Spicy, Extra Pork)';
COMMENT ON COLUMN menu_options.price IS 'Additional cost for this option in Thai Baht';
COMMENT ON COLUMN menu_options.is_available IS 'Whether this option is currently available for selection';

-- Create a view for easy querying of menu items with their options
CREATE OR REPLACE VIEW menu_items_with_options AS
SELECT 
    mi.id as menu_item_id,
    mi.name as menu_item_name,
    mi.price as base_price,
    mog.id as group_id,
    mog.name as group_name,
    mog.min_selection,
    mog.max_selection,
    mo.id as option_id,
    mo.name as option_name,
    mo.price as option_price,
    mo.is_available as option_available
FROM menu_items mi
LEFT JOIN menu_option_groups mog ON mi.id = mog.menu_item_id
LEFT JOIN menu_options mo ON mog.id = mo.group_id
ORDER BY mi.name, mog.name, mo.name;

COMMENT ON VIEW menu_items_with_options IS 'Convenient view for querying menu items with all their option groups and individual options';

-- Create a function to calculate total price with selected options
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
    
    -- Sum up prices of selected options
    SELECT COALESCE(SUM(price), 0) INTO options_price
    FROM menu_options
    WHERE id = ANY(p_selected_option_ids)
    AND is_available = true;
    
    -- Return total price
    RETURN COALESCE(base_price, 0) + options_price;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_menu_item_price IS 'Calculate total price of menu item including selected options';

-- Create a function to validate option selections
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
    
    -- Check each option group for this menu item
    FOR group_record IN 
        SELECT id, min_selection, max_selection
        FROM menu_option_groups
        WHERE menu_item_id = p_menu_item_id
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

COMMENT ON FUNCTION validate_option_selections IS 'Validate that selected options meet min/max constraints for each group';

-- Output summary
SELECT 
    'Menu Options Migration Completed' as status,
    NOW() as completed_at,
    (SELECT COUNT(*) FROM menu_option_groups) as option_groups_created,
    (SELECT COUNT(*) FROM menu_options) as options_created;
