-- ========================================
-- Food Ordering System Database Schema
-- ========================================

-- Add merchant_id to bookings table
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS merchant_id UUID REFERENCES profiles(id);

-- Create booking_items table for food order details
CREATE TABLE IF NOT EXISTS booking_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_booking_items_booking_id ON booking_items(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_items_menu_item_id ON booking_items(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_bookings_merchant_id ON bookings(merchant_id);
CREATE INDEX IF NOT EXISTS idx_bookings_service_type ON bookings(service_type);

-- Enable RLS on booking_items
ALTER TABLE booking_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for booking_items
-- 1. Customers can see their own booking items
CREATE POLICY "Customers can view their own booking items" ON booking_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = booking_items.booking_id 
            AND bookings.customer_id = auth.uid()
        )
    );

-- 2. Merchants can see booking items for their orders
CREATE POLICY "Merchants can view their restaurant booking items" ON booking_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = booking_items.booking_id 
            AND bookings.merchant_id = auth.uid()
        )
    );

-- 3. Drivers can see booking items for assigned jobs
CREATE POLICY "Drivers can view assigned booking items" ON booking_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = booking_items.booking_id 
            AND bookings.driver_id = auth.uid()
        )
    );

-- 4. Insert policy - only through system functions
CREATE POLICY "Restrict direct insert to booking_items" ON booking_items
    FOR INSERT WITH CHECK (false);

-- 5. Update policy - only through system functions  
CREATE POLICY "Restrict direct update to booking_items" ON booking_items
    FOR UPDATE USING (false);

-- 6. Delete policy - only through system functions
CREATE POLICY "Restrict direct delete to booking_items" ON booking_items
    FOR DELETE USING (false);

-- Function to create food order with items
CREATE OR REPLACE FUNCTION create_food_order(
    p_customer_id UUID,
    p_merchant_id UUID,
    p_items JSONB, -- [{"menu_item_id": "uuid", "quantity": 1, "price": 10.50, "name": "Item Name"}]
    p_pickup_address TEXT,
    p_dropoff_address TEXT,
    p_pickup_lat DECIMAL,
    p_pickup_lng DECIMAL,
    p_dropoff_lat DECIMAL,
    p_dropoff_lng DECIMAL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking_id UUID;
    v_total_price DECIMAL := 0;
    v_item JSONB;
    v_menu_item_id UUID;
    v_quantity INTEGER;
    v_price DECIMAL;
    v_name TEXT;
BEGIN
    -- Calculate total price
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_total_price := v_total_price + (v_item->>'price')::DECIMAL * (v_item->>'quantity')::INTEGER;
    END LOOP;
    
    -- Create booking
    INSERT INTO bookings (
        customer_id,
        service_type,
        status,
        merchant_id,
        pickup_address,
        destination_address,
        origin_lat,
        origin_lng,
        dest_lat,
        dest_lng,
        distance_km,
        price,
        created_at
    ) VALUES (
        p_customer_id,
        'food',
        'pending_merchant',
        p_merchant_id,
        p_pickup_address,
        p_dropoff_address,
        p_pickup_lat,
        p_pickup_lng,
        p_dropoff_lat,
        p_dropoff_lng,
        0.0, -- Default distance for food orders
        v_total_price,
        NOW()
    ) RETURNING id INTO v_booking_id;
    
    -- Insert booking items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_menu_item_id := (v_item->>'menu_item_id')::UUID;
        v_quantity := (v_item->>'quantity')::INTEGER;
        v_price := (v_item->>'price')::DECIMAL;
        v_name := v_item->>'name';
        
        INSERT INTO booking_items (
            booking_id,
            menu_item_id,
            quantity,
            price,
            name
        ) VALUES (
            v_booking_id,
            v_menu_item_id,
            v_quantity,
            v_price,
            v_name
        );
    END LOOP;
    
    RETURN v_booking_id;
END;
$$;

-- Function to get booking with items
CREATE OR REPLACE FUNCTION get_booking_with_items(p_booking_id UUID)
RETURNS TABLE (
    id UUID,
    customer_id UUID,
    service_type TEXT,
    status TEXT,
    merchant_id UUID,
    driver_id UUID,
    pickup_address TEXT,
    destination_address TEXT,
    origin_lat DECIMAL,
    origin_lng DECIMAL,
    dest_lat DECIMAL,
    dest_lng DECIMAL,
    price DECIMAL,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    items JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.customer_id,
        b.service_type,
        b.status,
        b.merchant_id,
        b.driver_id,
        b.pickup_address,
        b.destination_address,
        b.origin_lat,
        b.origin_lng,
        b.dest_lat,
        b.dest_lng,
        b.price,
        b.created_at,
        b.updated_at,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', bi.id,
                    'menu_item_id', bi.menu_item_id,
                    'quantity', bi.quantity,
                    'price', bi.price,
                    'name', bi.name
                )
            ) FILTER (WHERE bi.id IS NOT NULL),
            '[]'::jsonb
        ) as items
    FROM bookings b
    LEFT JOIN booking_items bi ON b.id = bi.booking_id
    WHERE b.id = p_booking_id
    GROUP BY b.id, b.customer_id, b.service_type, b.status, b.merchant_id, b.driver_id,
             b.pickup_address, b.destination_address, b.origin_lat, b.origin_lng,
             b.dest_lat, b.dest_lng, b.price, b.created_at, b.updated_at;
END;
$$;

-- Update existing RLS policies for bookings to include merchant access
CREATE POLICY "Merchants can view their restaurant bookings" ON bookings
    FOR SELECT USING (
        merchant_id = auth.uid()
    );

CREATE POLICY "Merchants can update their restaurant bookings" ON bookings
    FOR UPDATE USING (
        merchant_id = auth.uid()
    );

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_booking_items_updated_at
    BEFORE UPDATE ON booking_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL ON booking_items TO authenticated;
GRANT EXECUTE ON FUNCTION create_food_order TO authenticated;
GRANT EXECUTE ON FUNCTION get_booking_with_items TO authenticated;
