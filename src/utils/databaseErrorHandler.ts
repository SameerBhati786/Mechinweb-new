// Database error handling utilities for graceful error recovery
import { supabase } from '../lib/supabase';

export interface DatabaseError {
  code: string;
  message: string;
  details?: string;
  hint?: string;
}

export class DatabaseErrorHandler {
  // Handle system trigger errors gracefully
  static handleSystemTriggerError(error: any): { canRetry: boolean; message: string } {
    if (error.message?.includes('RI_ConstraintTrigger')) {
      return {
        canRetry: false,
        message: 'System constraint error detected. This operation cannot be performed due to database integrity constraints. Please contact support.'
      };
    }
    
    return {
      canRetry: true,
      message: 'Database operation failed. Please try again.'
    };
  }

  // Handle missing column errors
  static handleMissingColumnError(error: any): { canRetry: boolean; message: string; missingColumn?: string } {
    const columnMatch = error.message?.match(/column "([^"]+)" of relation "([^"]+)" does not exist/);
    
    if (columnMatch) {
      const [, columnName, tableName] = columnMatch;
      return {
        canRetry: false,
        message: `Database schema error: Missing column "${columnName}" in table "${tableName}". Please contact support.`,
        missingColumn: columnName
      };
    }
    
    return {
      canRetry: true,
      message: 'Database operation failed. Please try again.'
    };
  }

  // Generic database error handler
  static handleDatabaseError(error: any): { 
    canRetry: boolean; 
    message: string; 
    errorType: string;
    shouldReport: boolean;
  } {
    // System trigger errors
    if (error.message?.includes('RI_ConstraintTrigger')) {
      return {
        canRetry: false,
        message: 'Database constraint error. Please contact support.',
        errorType: 'SYSTEM_TRIGGER',
        shouldReport: true
      };
    }

    // Missing column errors
    if (error.message?.includes('does not exist') && error.message?.includes('column')) {
      return {
        canRetry: false,
        message: 'Database schema error. Please contact support.',
        errorType: 'MISSING_COLUMN',
        shouldReport: true
      };
    }

    // Permission errors
    if (error.message?.includes('permission denied')) {
      return {
        canRetry: false,
        message: 'Access denied. Please check your permissions.',
        errorType: 'PERMISSION_DENIED',
        shouldReport: true
      };
    }

    // Connection errors
    if (error.message?.includes('connection') || error.code === 'PGRST301') {
      return {
        canRetry: true,
        message: 'Connection error. Please try again.',
        errorType: 'CONNECTION_ERROR',
        shouldReport: false
      };
    }

    // RLS policy errors
    if (error.message?.includes('row-level security')) {
      return {
        canRetry: false,
        message: 'Access restricted. Please ensure you have proper permissions.',
        errorType: 'RLS_VIOLATION',
        shouldReport: true
      };
    }

    // Generic database error
    return {
      canRetry: true,
      message: 'Database operation failed. Please try again.',
      errorType: 'GENERIC_DB_ERROR',
      shouldReport: false
    };
  }

  // Safe update operation with error handling
  static async safeUpdate(
    table: string,
    updates: any,
    filter: any,
    retries: number = 2
  ): Promise<{ success: boolean; data?: any; error?: string }> {
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        const { data, error } = await supabase
          .from(table)
          .update(updates)
          .match(filter)
          .select();

        if (error) {
          const errorInfo = this.handleDatabaseError(error);
          
          if (!errorInfo.canRetry || attempt === retries) {
            return {
              success: false,
              error: errorInfo.message
            };
          }
          
          // Wait before retry
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
          continue;
        }

        return {
          success: true,
          data
        };
      } catch (error) {
        console.error(`Database update attempt ${attempt} failed:`, error);
        
        if (attempt === retries) {
          return {
            success: false,
            error: 'Database operation failed after multiple attempts'
          };
        }
      }
    }

    return {
      success: false,
      error: 'Maximum retry attempts exceeded'
    };
  }

  // Safe insert operation with error handling
  static async safeInsert(
    table: string,
    data: any,
    retries: number = 2
  ): Promise<{ success: boolean; data?: any; error?: string }> {
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        const { data: result, error } = await supabase
          .from(table)
          .insert(data)
          .select();

        if (error) {
          const errorInfo = this.handleDatabaseError(error);
          
          if (!errorInfo.canRetry || attempt === retries) {
            return {
              success: false,
              error: errorInfo.message
            };
          }
          
          // Wait before retry
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
          continue;
        }

        return {
          success: true,
          data: result
        };
      } catch (error) {
        console.error(`Database insert attempt ${attempt} failed:`, error);
        
        if (attempt === retries) {
          return {
            success: false,
            error: 'Database operation failed after multiple attempts'
          };
        }
      }
    }

    return {
      success: false,
      error: 'Maximum retry attempts exceeded'
    };
  }

  // Report critical errors for monitoring
  static async reportCriticalError(error: any, context: string): Promise<void> {
    try {
      const errorInfo = this.handleDatabaseError(error);
      
      if (errorInfo.shouldReport) {
        await supabase
          .from('purchase_audit_log')
          .insert([{
            client_id: null,
            service_id: null,
            action: 'CRITICAL_DATABASE_ERROR',
            details: {
              error_type: errorInfo.errorType,
              error_message: error.message,
              context,
              timestamp: new Date().toISOString(),
              stack: error.stack
            },
            success: false,
            error_message: error.message
          }]);
      }
    } catch (reportError) {
      console.error('Failed to report critical error:', reportError);
    }
  }

  // Database health check
  static async performHealthCheck(): Promise<{
    healthy: boolean;
    issues: string[];
    recommendations: string[];
  }> {
    const issues: string[] = [];
    const recommendations: string[] = [];

    try {
      // Test basic connectivity
      const { error: connectError } = await supabase
        .from('services')
        .select('count(*)')
        .limit(1);

      if (connectError) {
        issues.push(`Database connectivity issue: ${connectError.message}`);
        recommendations.push('Check database connection and credentials');
      }

      // Test RLS policies
      const { error: rlsError } = await supabase
        .from('services')
        .select('id')
        .limit(1);

      if (rlsError && rlsError.message?.includes('row-level security')) {
        issues.push('RLS policy configuration issue');
        recommendations.push('Review and update row-level security policies');
      }

      // Test for missing columns (try to select updated_at)
      const { error: columnError } = await supabase
        .from('services')
        .select('updated_at')
        .limit(1);

      if (columnError && columnError.message?.includes('does not exist')) {
        issues.push('Missing updated_at column in services table');
        recommendations.push('Run database migration to add missing columns');
      }

    } catch (error) {
      issues.push(`Health check failed: ${error.message}`);
      recommendations.push('Contact database administrator');
    }

    return {
      healthy: issues.length === 0,
      issues,
      recommendations
    };
  }
}

// Global error handler for database operations
export const withDatabaseErrorHandling = async <T>(
  operation: () => Promise<T>,
  context: string = 'database_operation'
): Promise<T> => {
  try {
    return await operation();
  } catch (error) {
    console.error(`Database operation failed in ${context}:`, error);
    
    const errorInfo = DatabaseErrorHandler.handleDatabaseError(error);
    
    // Report critical errors
    if (errorInfo.shouldReport) {
      await DatabaseErrorHandler.reportCriticalError(error, context);
    }
    
    // Throw user-friendly error
    throw new Error(errorInfo.message);
  }
};