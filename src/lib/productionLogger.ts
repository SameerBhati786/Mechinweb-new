// Production-ready logging service for debugging and monitoring
export class ProductionLogger {
  private static instance: ProductionLogger;
  private logs: Array<{
    timestamp: string;
    level: string;
    message: string;
    data?: any;
  }> = [];

  private constructor() {}

  static getInstance(): ProductionLogger {
    if (!ProductionLogger.instance) {
      ProductionLogger.instance = new ProductionLogger();
    }
    return ProductionLogger.instance;
  }

  log(level: 'info' | 'error' | 'warn', message: string, data?: any): void {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level: level.toUpperCase(),
      message,
      data: data ? JSON.stringify(data, null, 2) : undefined
    };

    this.logs.push(logEntry);
    
    // Keep only last 1000 logs to prevent memory issues
    if (this.logs.length > 1000) {
      this.logs = this.logs.slice(-1000);
    }

    // Console output for development
    if (import.meta.env.DEV) {
      console.log(`[${logEntry.timestamp}] ${logEntry.level}: ${message}`, data || '');
    }
  }

  getLogs(): Array<any> {
    return [...this.logs];
  }

  clearLogs(): void {
    this.logs = [];
  }
}