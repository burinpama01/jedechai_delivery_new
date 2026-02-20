-- Merchant Database Schema
-- Create tables for food delivery management

-- Create menu_items table
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    price FLOAT NOT NULL CHECK (price >= 0),
    image_url TEXT,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_menu_items_merchant_id ON menu_items(merchant_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_is_available ON menu_items(is_available);
CREATE INDEX IF NOT EXISTS idx_menu_items_created_at ON menu_items(created_at);

-- Enable RLS on menu_items table
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for menu_items
DO $$
BEGIN
    -- Create policy for merchants to view their own items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'menu_items' 
        AND policyname = 'Merchants can view their own menu items'
    ) THEN
        CREATE POLICY "Merchants can view their own menu items" ON menu_items
        FOR SELECT USING (auth.uid() = merchant_id);
    END IF;
    
    -- Create policy for merchants to insert their own items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'menu_items' 
        AND policyname = 'Merchants can insert their own menu items'
    ) THEN
        CREATE POLICY "Merchants can insert their own menu items" ON menu_items
        FOR INSERT WITH CHECK (auth.uid() = merchant_id);
    END IF;
    
    -- Create policy for merchants to update their own items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'menu_items' 
        AND policyname = 'Merchants can update their own menu items'
    ) THEN
        CREATE POLICY "Merchants can update their own menu items" ON menu_items
        FOR UPDATE USING (auth.uid() = merchant_id) WITH CHECK (auth.uid() = merchant_id);
    END IF;
    
    -- Create policy for merchants to delete their own items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'menu_items' 
        AND policyname = 'Merchants can delete their own menu items'
    ) THEN
        CREATE POLICY "Merchants can delete their own menu items" ON menu_items
        FOR DELETE USING (auth.uid() = merchant_id);
    END IF;
    
    -- Create policy for customers to view available menu items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'menu_items' 
        AND policyname = 'Customers can view available menu items'
    ) THEN
        CREATE POLICY "Customers can view available menu items" ON menu_items
        FOR SELECT USING (is_available = true);
    END IF;
END $$;

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic updated_at
DROP TRIGGER IF EXISTS menu_items_updated_at_trigger ON menu_items;
CREATE TRIGGER menu_items_updated_at_trigger
    BEFORE UPDATE ON menu_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create food_orders table for future use
CREATE TABLE IF NOT EXISTS food_orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    customer_id UUID REFERENCES auth.users(id),
    merchant_id UUID REFERENCES auth.users(id),
    items JSONB NOT NULL, -- Array of menu items with quantities
    total_price FLOAT NOT NULL CHECK (total_price >= 0),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'ready', 'delivering', 'completed', 'cancelled')),
    delivery_address TEXT,
    customer_phone TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for food_orders
CREATE INDEX IF NOT EXISTS idx_food_orders_merchant_id ON food_orders(merchant_id);
CREATE INDEX IF NOT EXISTS idx_food_orders_customer_id ON food_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_food_orders_status ON food_orders(status);
CREATE INDEX IF NOT EXISTS idx_food_orders_created_at ON food_orders(created_at);

-- Enable RLS on food_orders table
ALTER TABLE food_orders ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for food_orders
DO $$
BEGIN
    -- Create policy for merchants to view their own orders
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'food_orders' 
        AND policyname = 'Merchants can view their own orders'
    ) THEN
        CREATE POLICY "Merchants can view their own orders" ON food_orders
        FOR SELECT USING (auth.uid() = merchant_id);
    END IF;
    
    -- Create policy for merchants to update their own orders
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'food_orders' 
        AND policyname = 'Merchants can update their own orders'
    ) THEN
        CREATE POLICY "Merchants can update their own orders" ON food_orders
        FOR UPDATE USING (auth.uid() = merchant_id) WITH CHECK (auth.uid() = merchant_id);
    END IF;
    
    -- Create policy for customers to view their own orders
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'food_orders' 
        AND policyname = 'Customers can view their own orders'
    ) THEN
        CREATE POLICY "Customers can view their own orders" ON food_orders
        FOR SELECT USING (auth.uid() = customer_id);
    END IF;
    
    -- Create policy for customers to insert their own orders
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'food_orders' 
        AND policyname = 'Customers can insert their own orders'
    ) THEN
        CREATE POLICY "Customers can insert their own orders" ON food_orders
        FOR INSERT WITH CHECK (auth.uid() = customer_id);
    END IF;
END $$;

-- Create trigger for automatic updated_at on food_orders
DROP TRIGGER IF EXISTS food_orders_updated_at_trigger ON food_orders;
CREATE TRIGGER food_orders_updated_at_trigger
    BEFORE UPDATE ON food_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add shop_status column to profiles table for merchants
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS shop_status BOOLEAN DEFAULT false;

-- Create index for shop_status
CREATE INDEX IF NOT EXISTS idx_profiles_shop_status ON profiles(shop_status);

-- Create RLS policy for shop_status updates
DO $$
BEGIN
    -- Create policy for merchants to update their shop status
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'profiles' 
        AND policyname = 'Merchants can update their shop status'
    ) THEN
        CREATE POLICY "Merchants can update their shop status" ON profiles
        FOR UPDATE USING (auth.uid() = id AND role = 'merchant') WITH CHECK (auth.uid() = id AND role = 'merchant');
    END IF;
END $$;

-- Sample data for testing (optional)
-- INSERT INTO menu_items (merchant_id, name, description, price, image_url, is_available)
-- VALUES 
--     ('your-merchant-id', 'กะเพราหมูปลอด', 'กะเพราหมูปลอดสูตรเด็ด', 50.0, 'https://example.com/kaprao.jpg', true),
--     ('your-merchant-id', 'ข้าวผัดไข่', 'ข้าวผัดไข่รสเดิม', 40.0, 'https://example.com/khaopad.jpg', true);

COMMIT;
