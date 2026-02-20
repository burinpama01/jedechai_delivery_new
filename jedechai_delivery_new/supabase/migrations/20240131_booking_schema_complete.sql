-- Complete Bookings Table Schema for Supabase
-- Compatible with both old and new code

-- Drop existing table if it exists (for development)
DROP TABLE IF EXISTS public.bookings CASCADE;

-- Create bookings table with all required fields
CREATE TABLE public.bookings (
    -- Primary identification
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- User references
    customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    driver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    merchant_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    
    -- Service information
    service_type TEXT NOT NULL CHECK (service_type IN ('ride', 'food', 'parcel')),
    service_id TEXT, -- Legacy field for backward compatibility
    
    -- Location data
    origin_lat DOUBLE PRECISION NOT NULL,
    origin_lng DOUBLE PRECISION NOT NULL,
    dest_lat DOUBLE PRECISION NOT NULL,
    dest_lng DOUBLE PRECISION NOT NULL,
    
    -- Address fields (both old and new naming)
    origin_address TEXT,
    pickup_address TEXT, -- New preferred field
    dest_address TEXT,
    destination_address TEXT, -- New preferred field
    
    -- Trip details
    distance_km DOUBLE PRECISION NOT NULL,
    
    -- Pricing fields (both old and new)
    delivery_fee DOUBLE PRECISION DEFAULT 0, -- Legacy field
    food_cost DOUBLE PRECISION, -- Legacy field
    total_amount DOUBLE PRECISION DEFAULT 0, -- Legacy field
    price DOUBLE PRECISION NOT NULL DEFAULT 0, -- New preferred field
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'searching', 'confirmed', 'driver_assigned', 'in_progress', 'completed', 'cancelled', 'accepted')),
    
    -- Driver information
    driver_name TEXT,
    driver_phone TEXT,
    driver_vehicle TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE, -- Legacy field
    assigned_at TIMESTAMP WITH TIME ZONE, -- New preferred field
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Additional metadata
    notes TEXT,
    cancellation_reason TEXT, -- Legacy field
    payment_method TEXT DEFAULT 'cash' CHECK (payment_method IN ('cash', 'card', 'wallet')),
    details JSONB DEFAULT '{}', -- Legacy field
    
    -- Constraints
    CONSTRAINT valid_coordinates CHECK (
        origin_lat >= -90 AND origin_lat <= 90 AND
        origin_lng >= -180 AND origin_lng <= 180 AND
        dest_lat >= -90 AND dest_lat <= 90 AND
        dest_lng >= -180 AND dest_lng <= 180
    ),
    CONSTRAINT positive_distance CHECK (distance_km > 0),
    CONSTRAINT positive_price CHECK (price >= 0),
    CONSTRAINT positive_total_amount CHECK (total_amount >= 0),
    CONSTRAINT positive_delivery_fee CHECK (delivery_fee >= 0)
);

-- Create indexes for better performance
CREATE INDEX idx_bookings_customer_id ON public.bookings(customer_id);
CREATE INDEX idx_bookings_driver_id ON public.bookings(driver_id);
CREATE INDEX idx_bookings_merchant_id ON public.bookings(merchant_id);
CREATE INDEX idx_bookings_status ON public.bookings(status);
CREATE INDEX idx_bookings_service_type ON public.bookings(service_type);
CREATE INDEX idx_bookings_created_at ON public.bookings(created_at DESC);
CREATE INDEX idx_bookings_location ON public.bookings(origin_lat, origin_lng);
CREATE INDEX idx_bookings_pending ON public.bookings(status) WHERE status = 'pending';

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_bookings_updated_at 
    BEFORE UPDATE ON public.bookings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create view for backward compatibility
CREATE OR REPLACE VIEW public.bookings_legacy AS
SELECT 
    id,
    customer_id,
    driver_id,
    service_id, -- Map from service_type
    merchant_id,
    origin_lat,
    origin_lng,
    COALESCE(pickup_address, origin_address) as origin_address,
    dest_lat,
    dest_lng,
    COALESCE(destination_address, dest_address) as dest_address,
    distance_km,
    COALESCE(delivery_fee, price) as delivery_fee,
    food_cost,
    COALESCE(total_amount, price) as total_amount,
    status,
    created_at,
    COALESCE(assigned_at, accepted_at) as accepted_at,
    completed_at,
    COALESCE(delivery_fee, price) as delivery_fee,
    food_cost,
    COALESCE(total_amount, price) as total_amount,
    details
FROM public.bookings;

-- Enable Row Level Security (RLS)
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- 1. Users can view their own bookings
CREATE POLICY "Users can view own bookings" ON public.bookings
    FOR SELECT USING (auth.uid() = customer_id);

-- 2. Users can insert their own bookings
CREATE POLICY "Users can insert own bookings" ON public.bookings
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- 3. Users can update their own bookings (for cancellation)
CREATE POLICY "Users can update own bookings" ON public.bookings
    FOR UPDATE USING (auth.uid() = customer_id);

-- 4. Drivers can view assigned bookings
CREATE POLICY "Drivers can view assigned bookings" ON public.bookings
    FOR SELECT USING (auth.uid() = driver_id);

-- 5. Drivers can update assigned bookings
CREATE POLICY "Drivers can update assigned bookings" ON public.bookings
    FOR UPDATE USING (auth.uid() = driver_id);

-- 6. Drivers can view pending bookings
CREATE POLICY "Drivers can view pending bookings" ON public.bookings
    FOR SELECT USING (status = 'pending' AND driver_id IS NULL);

-- Grant permissions
GRANT ALL ON public.bookings TO authenticated;
GRANT SELECT ON public.bookings TO anon;
GRANT SELECT ON public.bookings_legacy TO authenticated;
GRANT SELECT ON public.bookings_legacy TO anon;

-- Create function to handle legacy field mapping
CREATE OR REPLACE FUNCTION public.map_legacy_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Map service_type to service_id for legacy compatibility
    IF NEW.service_id IS NULL AND NEW.service_type IS NOT NULL THEN
        NEW.service_id = NEW.service_type;
    END IF;
    
    -- Map addresses
    IF NEW.pickup_address IS NULL AND NEW.origin_address IS NOT NULL THEN
        NEW.pickup_address = NEW.origin_address;
    END IF;
    
    IF NEW.destination_address IS NULL AND NEW.dest_address IS NOT NULL THEN
        NEW.destination_address = NEW.dest_address;
    END IF;
    
    -- Map pricing
    IF NEW.price = 0 AND NEW.total_amount > 0 THEN
        NEW.price = NEW.total_amount;
    ELSIF NEW.price = 0 AND NEW.delivery_fee > 0 THEN
        NEW.price = NEW.delivery_fee;
    END IF;
    
    IF NEW.total_amount = 0 AND NEW.price > 0 THEN
        NEW.total_amount = NEW.price;
    END IF;
    
    IF NEW.delivery_fee = 0 AND NEW.price > 0 THEN
        NEW.delivery_fee = NEW.price;
    END IF;
    
    -- Map timestamps
    IF NEW.assigned_at IS NULL AND NEW.accepted_at IS NOT NULL THEN
        NEW.assigned_at = NEW.accepted_at;
    END IF;
    
    IF NEW.accepted_at IS NULL AND NEW.assigned_at IS NOT NULL THEN
        NEW.accepted_at = NEW.assigned_at;
    END IF;
    
    -- Map cancellation reason
    IF NEW.notes IS NULL AND NEW.cancellation_reason IS NOT NULL THEN
        NEW.notes = NEW.cancellation_reason;
    END IF;
    
    IF NEW.cancellation_reason IS NULL AND NEW.notes IS NOT NULL AND NEW.status = 'cancelled' THEN
        NEW.cancellation_reason = NEW.notes;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for legacy field mapping
CREATE TRIGGER map_legacy_fields_trigger
    BEFORE INSERT OR UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.map_legacy_fields();

-- Comments for documentation
COMMENT ON TABLE public.bookings IS 'Complete bookings table supporting ride, food, and parcel services with backward compatibility';
COMMENT ON COLUMN public.bookings.id IS 'Unique identifier for each booking';
COMMENT ON COLUMN public.bookings.customer_id IS 'Reference to the customer who made the booking';
COMMENT ON COLUMN public.bookings.driver_id IS 'Reference to the assigned driver';
COMMENT ON COLUMN public.bookings.merchant_id IS 'Reference to the merchant (for food/parcel)';
COMMENT ON COLUMN public.bookings.service_type IS 'Type of service: ride, food, or parcel';
COMMENT ON COLUMN public.bookings.service_id IS 'Legacy field for backward compatibility';
COMMENT ON COLUMN public.bookings.origin_lat IS 'Pickup location latitude';
COMMENT ON COLUMN public.bookings.origin_lng IS 'Pickup location longitude';
COMMENT ON COLUMN public.bookings.origin_address IS 'Legacy pickup address field';
COMMENT ON COLUMN public.bookings.pickup_address IS 'Pickup address (preferred field)';
COMMENT ON COLUMN public.bookings.dest_lat IS 'Destination latitude';
COMMENT ON COLUMN public.bookings.dest_lng IS 'Destination longitude';
COMMENT ON COLUMN public.bookings.dest_address IS 'Legacy destination address field';
COMMENT ON COLUMN public.bookings.destination_address IS 'Destination address (preferred field)';
COMMENT ON COLUMN public.bookings.distance_km IS 'Distance in kilometers';
COMMENT ON COLUMN public.bookings.delivery_fee IS 'Legacy delivery fee field';
COMMENT ON COLUMN public.bookings.food_cost IS 'Legacy food cost field';
COMMENT ON COLUMN public.bookings.total_amount IS 'Legacy total amount field';
COMMENT ON COLUMN public.bookings.price IS 'Price (preferred field)';
COMMENT ON COLUMN public.bookings.status IS 'Current status of the booking';
COMMENT ON COLUMN public.bookings.driver_name IS 'Name of the assigned driver';
COMMENT ON COLUMN public.bookings.driver_phone IS 'Phone number of the assigned driver';
COMMENT ON COLUMN public.bookings.driver_vehicle IS 'Vehicle information of the assigned driver';
COMMENT ON COLUMN public.bookings.created_at IS 'When the booking was created';
COMMENT ON COLUMN public.bookings.updated_at IS 'Last time the booking was updated';
COMMENT ON COLUMN public.bookings.accepted_at IS 'Legacy timestamp when booking was accepted';
COMMENT ON COLUMN public.bookings.assigned_at IS 'Timestamp when driver was assigned';
COMMENT ON COLUMN public.bookings.started_at IS 'Timestamp when trip started';
COMMENT ON COLUMN public.bookings.completed_at IS 'Timestamp when trip completed';
COMMENT ON COLUMN public.bookings.notes IS 'Additional notes';
COMMENT ON COLUMN public.bookings.cancellation_reason IS 'Legacy cancellation reason field';
COMMENT ON COLUMN public.bookings.payment_method IS 'Payment method: cash, card, or wallet';
COMMENT ON COLUMN public.bookings.details IS 'Legacy additional details field';

-- Sample data for testing (optional)
-- INSERT INTO public.bookings (customer_id, service_type, origin_lat, origin_lng, dest_lat, dest_lng, distance_km, price, status) 
-- VALUES 
-- ('test-user-id', 'ride', 13.7563, 100.5018, 13.7468, 100.5350, 5.2, 87.0, 'pending');
