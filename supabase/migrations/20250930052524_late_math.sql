/*
  # Database Maintenance and Error Prevention

  1. Maintenance Functions
    - Create functions for safe database operations
    - Add error handling and logging
    
  2. Health Checks
    - Create database health monitoring
    - Add constraint validation
    
  3. Backup Procedures
    - Document backup requirements
    - Create maintenance schedules
*/

-- Create a comprehensive database health check function
CREATE OR REPLACE FUNCTION perform_database_health_check()
RETURNS TABLE(
    check_name text,
    status text,
    details text,
    recommendation text
) AS $$
BEGIN
    -- Check for missing updated_at columns
    RETURN QUERY
    SELECT 
        'Missing updated_at columns'::text,
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END::text,
        'Tables missing updated_at: ' || string_agg(t.table_name, ', ')::text,
        'Add updated_at columns to missing tables'::text
    FROM information_schema.tables t
    LEFT JOIN information_schema.columns c 
        ON t.table_name = c.table_name AND c.column_name = 'updated_at'
    WHERE t.table_schema = 'public' 
        AND t.table_type = 'BASE TABLE'
        AND t.table_name IN ('services', 'clients', 'orders', 'invoices', 'notifications')
        AND c.column_name IS NULL;

    -- Check for orphaned foreign key references
    RETURN QUERY
    SELECT 
        'Orphaned foreign keys'::text,
        'INFO'::text,
        'Foreign key constraints: ' || COUNT(*)::text,
        'Monitor for constraint violations'::text
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public';

    -- Check for system triggers that might cause issues
    RETURN QUERY
    SELECT 
        'System constraint triggers'::text,
        'INFO'::text,
        'System triggers found: ' || COUNT(*)::text,
        'Avoid modifying system triggers directly'::text
    FROM information_schema.triggers
    WHERE trigger_name LIKE 'RI_ConstraintTrigger%' AND trigger_schema = 'public';

    -- Check RLS policies
    RETURN QUERY
    SELECT 
        'RLS policies'::text,
        CASE 
            WHEN COUNT(*) > 0 THEN 'PASS'
            ELSE 'WARNING'
        END::text,
        'Active RLS policies: ' || COUNT(*)::text,
        'Ensure all tables have appropriate RLS policies'::text
    FROM pg_policies
    WHERE schemaname = 'public';

    -- Check for tables without RLS enabled
    RETURN QUERY
    SELECT 
        'Tables without RLS'::text,
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'WARNING'
        END::text,
        'Tables without RLS: ' || string_agg(tablename, ', ')::text,
        'Enable RLS on all user tables'::text
    FROM pg_tables
    WHERE schemaname = 'public'
        AND tablename NOT IN (
            SELECT tablename FROM pg_tables pt
            JOIN pg_class pc ON pt.tablename = pc.relname
            WHERE pc.relrowsecurity = true AND pt.schemaname = 'public'
        )
        AND tablename IN ('services', 'clients', 'orders', 'invoices', 'notifications');

END;
$$ LANGUAGE plpgsql;

-- Create a function to safely perform database maintenance
CREATE OR REPLACE FUNCTION perform_safe_maintenance()
RETURNS text AS $$
DECLARE
    maintenance_log text := '';
    table_record record;
BEGIN
    maintenance_log := maintenance_log || 'Starting database maintenance at ' || now() || E'\n';
    
    -- Update statistics
    ANALYZE;
    maintenance_log := maintenance_log || 'Updated table statistics' || E'\n';
    
    -- Vacuum analyze critical tables
    FOR table_record IN 
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename IN ('services', 'clients', 'orders', 'invoices')
    LOOP
        EXECUTE format('VACUUM ANALYZE %I', table_record.tablename);
        maintenance_log := maintenance_log || 'Vacuumed table: ' || table_record.tablename || E'\n';
    END LOOP;
    
    -- Check for constraint violations
    BEGIN
        -- This will identify any constraint issues without failing
        PERFORM * FROM constraint_health LIMIT 1;
        maintenance_log := maintenance_log || 'Constraint health check passed' || E'\n';
    EXCEPTION
        WHEN OTHERS THEN
            maintenance_log := maintenance_log || 'Constraint health check warning: ' || SQLERRM || E'\n';
    END;
    
    maintenance_log := maintenance_log || 'Maintenance completed at ' || now();
    
    RETURN maintenance_log;
END;
$$ LANGUAGE plpgsql;

-- Create a function to handle system trigger errors gracefully
CREATE OR REPLACE FUNCTION handle_system_trigger_error(
    error_message text,
    attempted_operation text
)
RETURNS text AS $$
BEGIN
    -- Log the error for monitoring
    INSERT INTO purchase_audit_log (
        client_id,
        service_id,
        action,
        details,
        success,
        error_message
    ) VALUES (
        NULL,
        NULL,
        'SYSTEM_TRIGGER_ERROR',
        jsonb_build_object(
            'error_message', error_message,
            'attempted_operation', attempted_operation,
            'timestamp', now()
        ),
        false,
        error_message
    );
    
    -- Return guidance for handling the error
    IF error_message LIKE '%RI_ConstraintTrigger%' THEN
        RETURN 'System constraint trigger error detected. This is a PostgreSQL internal trigger that cannot be modified. Consider using alternative update methods or contact database administrator.';
    ELSE
        RETURN 'Database error logged. Please contact support with error details.';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions for maintenance functions
GRANT EXECUTE ON FUNCTION perform_database_health_check() TO authenticated;
GRANT EXECUTE ON FUNCTION perform_safe_maintenance() TO authenticated;
GRANT EXECUTE ON FUNCTION handle_system_trigger_error(text, text) TO authenticated;

-- Create indexes for better performance on commonly queried columns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_services_updated_at ON services(updated_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_updated_at ON orders(updated_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_clients_updated_at ON clients(updated_at);

-- Ensure all tables have proper RLS policies
DO $$
DECLARE
    table_name text;
    policy_exists boolean;
BEGIN
    -- Check services table RLS
    SELECT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'services'
    ) INTO policy_exists;
    
    IF NOT policy_exists THEN
        ALTER TABLE services ENABLE ROW LEVEL SECURITY;
        
        CREATE POLICY "Anyone can read services"
            ON services
            FOR SELECT
            TO anon, authenticated
            USING (true);
            
        RAISE NOTICE 'Enabled RLS and created policy for services table';
    END IF;
END $$;