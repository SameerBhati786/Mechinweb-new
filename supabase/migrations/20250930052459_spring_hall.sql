/*
  # Fix System Trigger Permission Issues

  1. System Triggers
    - Identify and handle system triggers that cannot be modified
    - Create alternative solutions for constraint triggers
    
  2. Constraint Management
    - Review foreign key constraints
    - Ensure proper constraint naming and management
    
  3. Permissions
    - Grant appropriate permissions for database operations
    - Avoid modifying system-level triggers
*/

-- First, let's identify all system triggers that might be causing issues
SELECT 
    t.trigger_name,
    t.event_object_table,
    t.trigger_schema,
    t.action_timing,
    t.event_manipulation,
    CASE 
        WHEN t.trigger_name LIKE 'RI_ConstraintTrigger%' THEN 'SYSTEM_CONSTRAINT'
        WHEN t.trigger_name LIKE 'pg_%' THEN 'SYSTEM_INTERNAL'
        ELSE 'USER_DEFINED'
    END as trigger_type
FROM information_schema.triggers t
WHERE t.trigger_schema = 'public'
ORDER BY trigger_type, t.event_object_table, t.trigger_name;

-- Create a function to safely handle constraint operations
CREATE OR REPLACE FUNCTION safe_constraint_operation(
    operation_type text,
    table_name text,
    constraint_name text DEFAULT NULL
)
RETURNS text AS $$
DECLARE
    result text;
    constraint_exists boolean;
BEGIN
    -- Check if we're dealing with a system constraint
    IF constraint_name IS NOT NULL AND constraint_name LIKE 'RI_ConstraintTrigger%' THEN
        RETURN 'SKIPPED: System constraint trigger cannot be modified';
    END IF;
    
    -- Handle different operations safely
    CASE operation_type
        WHEN 'DROP_CONSTRAINT' THEN
            -- Check if constraint exists before dropping
            SELECT EXISTS (
                SELECT 1 FROM information_schema.table_constraints 
                WHERE table_name = safe_constraint_operation.table_name 
                AND constraint_name = safe_constraint_operation.constraint_name
            ) INTO constraint_exists;
            
            IF constraint_exists THEN
                EXECUTE format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I', table_name, constraint_name);
                result := 'DROPPED: ' || constraint_name;
            ELSE
                result := 'NOT_FOUND: ' || constraint_name;
            END IF;
            
        WHEN 'VALIDATE_CONSTRAINTS' THEN
            -- Validate all constraints on the table
            EXECUTE format('ALTER TABLE %I VALIDATE CONSTRAINT ALL', table_name);
            result := 'VALIDATED: All constraints on ' || table_name;
            
        ELSE
            result := 'UNKNOWN_OPERATION: ' || operation_type;
    END CASE;
    
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Fix any orphaned or problematic foreign key constraints
DO $$
DECLARE
    fk_record record;
    result text;
BEGIN
    -- Get all foreign key constraints
    FOR fk_record IN 
        SELECT 
            tc.table_name,
            tc.constraint_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
            ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu 
            ON ccu.constraint_name = tc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_schema = 'public'
    LOOP
        -- Validate that the foreign key relationship is still valid
        BEGIN
            EXECUTE format('ALTER TABLE %I VALIDATE CONSTRAINT %I', 
                fk_record.table_name, fk_record.constraint_name);
            RAISE NOTICE 'Validated FK constraint: %.%', fk_record.table_name, fk_record.constraint_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'FK constraint validation failed: %.% - %', 
                    fk_record.table_name, fk_record.constraint_name, SQLERRM;
        END;
    END LOOP;
END $$;

-- Create a function to safely update records without triggering system constraint issues
CREATE OR REPLACE FUNCTION safe_update_with_constraints(
    target_table text,
    update_columns text,
    where_clause text
)
RETURNS text AS $$
DECLARE
    sql_query text;
    result text;
BEGIN
    -- Disable triggers temporarily for system constraint issues
    sql_query := format('ALTER TABLE %I DISABLE TRIGGER USER', target_table);
    EXECUTE sql_query;
    
    -- Perform the update
    sql_query := format('UPDATE %I SET %s WHERE %s', target_table, update_columns, where_clause);
    EXECUTE sql_query;
    GET DIAGNOSTICS result = ROW_COUNT;
    
    -- Re-enable triggers
    sql_query := format('ALTER TABLE %I ENABLE TRIGGER USER', target_table);
    EXECUTE sql_query;
    
    RETURN 'Updated ' || result || ' rows in ' || target_table;
EXCEPTION
    WHEN OTHERS THEN
        -- Ensure triggers are re-enabled even if update fails
        BEGIN
            EXECUTE format('ALTER TABLE %I ENABLE TRIGGER USER', target_table);
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Ignore errors when re-enabling
        END;
        
        RAISE EXCEPTION 'Safe update failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions for the new functions
GRANT EXECUTE ON FUNCTION safe_constraint_operation(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION safe_update_with_constraints(text, text, text) TO authenticated;

-- Create a view to monitor constraint health
CREATE OR REPLACE VIEW constraint_health AS
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    CASE 
        WHEN tc.constraint_name LIKE 'RI_ConstraintTrigger%' THEN 'SYSTEM'
        ELSE 'USER'
    END as constraint_category,
    CASE 
        WHEN tc.is_deferrable = 'YES' THEN 'DEFERRABLE'
        ELSE 'IMMEDIATE'
    END as deferrable_status
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- Grant access to the health view
GRANT SELECT ON constraint_health TO authenticated;
GRANT SELECT ON constraint_health TO anon;