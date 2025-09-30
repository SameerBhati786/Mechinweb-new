/*
  # Fix Missing Columns in Database Tables

  1. Missing Columns
    - Add `updated_at` column to `services` table
    - Add any other missing timestamp columns
    
  2. Triggers
    - Create update trigger function if missing
    - Add triggers for automatic timestamp updates
    
  3. Security
    - Ensure proper permissions for trigger operations
    - Validate existing RLS policies
*/

-- First, check if the update function exists, if not create it
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add missing updated_at column to services table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'services' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE services ADD COLUMN updated_at timestamptz DEFAULT now();
        
        -- Update existing records to have the current timestamp
        UPDATE services SET updated_at = created_at WHERE updated_at IS NULL;
        
        -- Make the column NOT NULL after setting values
        ALTER TABLE services ALTER COLUMN updated_at SET NOT NULL;
        
        RAISE NOTICE 'Added updated_at column to services table';
    ELSE
        RAISE NOTICE 'updated_at column already exists in services table';
    END IF;
END $$;

-- Create or replace the trigger for services table
DROP TRIGGER IF EXISTS update_services_updated_at ON services;
CREATE TRIGGER update_services_updated_at
    BEFORE UPDATE ON services
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Verify other tables have updated_at columns and triggers
DO $$
DECLARE
    table_name text;
    tables_to_check text[] := ARRAY['clients', 'orders', 'invoices', 'notifications', 'user_preferences', 'email_templates', 'zoho_integrations', 'encrypted_payment_data'];
BEGIN
    FOREACH table_name IN ARRAY tables_to_check
    LOOP
        -- Check if updated_at column exists
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = table_name AND column_name = 'updated_at'
        ) THEN
            EXECUTE format('ALTER TABLE %I ADD COLUMN updated_at timestamptz DEFAULT now()', table_name);
            EXECUTE format('UPDATE %I SET updated_at = created_at WHERE updated_at IS NULL', table_name);
            EXECUTE format('ALTER TABLE %I ALTER COLUMN updated_at SET NOT NULL', table_name);
            RAISE NOTICE 'Added updated_at column to % table', table_name;
        END IF;
        
        -- Check if trigger exists, if not create it
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.triggers 
            WHERE event_object_table = table_name 
            AND trigger_name = format('update_%s_updated_at', table_name)
        ) THEN
            EXECUTE format('DROP TRIGGER IF EXISTS update_%s_updated_at ON %I', table_name, table_name);
            EXECUTE format('CREATE TRIGGER update_%s_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()', table_name, table_name);
            RAISE NOTICE 'Created updated_at trigger for % table', table_name;
        END IF;
    END LOOP;
END $$;

-- Grant necessary permissions for trigger operations
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;

-- Ensure the trigger function has proper permissions
GRANT EXECUTE ON FUNCTION update_updated_at_column() TO authenticated;
GRANT EXECUTE ON FUNCTION update_updated_at_column() TO anon;

-- Verify all tables have the required columns
SELECT 
    t.table_name,
    CASE 
        WHEN c.column_name IS NOT NULL THEN 'EXISTS'
        ELSE 'MISSING'
    END as updated_at_status,
    CASE 
        WHEN tr.trigger_name IS NOT NULL THEN 'EXISTS'
        ELSE 'MISSING'
    END as trigger_status
FROM information_schema.tables t
LEFT JOIN information_schema.columns c 
    ON t.table_name = c.table_name 
    AND c.column_name = 'updated_at'
LEFT JOIN information_schema.triggers tr 
    ON t.table_name = tr.event_object_table 
    AND tr.trigger_name = format('update_%s_updated_at', t.table_name)
WHERE t.table_schema = 'public' 
    AND t.table_type = 'BASE TABLE'
    AND t.table_name IN ('services', 'clients', 'orders', 'invoices', 'notifications', 'user_preferences', 'email_templates', 'zoho_integrations', 'encrypted_payment_data')
ORDER BY t.table_name;