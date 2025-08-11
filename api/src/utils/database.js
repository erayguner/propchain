import pg from 'pg';
import { logger } from './logger.js';

const { Pool } = pg;

// Database configuration
const dbConfig = {
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
  connectionTimeoutMillis: 2000, // Return an error after 2 seconds if connection could not be established
  statement_timeout: 10000, // Terminate any statement that takes more than 10 seconds
  query_timeout: 10000, // Terminate any query that takes more than 10 seconds
};

// Create connection pool
export const db = new Pool(dbConfig);

// Handle pool events
db.on('connect', (client) => {
  logger.debug('New database client connected');
});

db.on('error', (err, client) => {
  logger.error('Unexpected error on idle database client:', err);
});

// Helper function to execute queries with logging
export const query = async (text, params) => {
  const start = Date.now();
  
  try {
    const res = await db.query(text, params);
    const duration = Date.now() - start;
    
    logger.debug('Database query executed', {
      query: text,
      duration,
      rows: res.rowCount
    });
    
    return res;
  } catch (error) {
    const duration = Date.now() - start;
    
    logger.error('Database query failed', {
      query: text,
      error: error.message,
      duration
    });
    
    throw error;
  }
};

// Helper function to execute transactions
export const transaction = async (callback) => {
  const client = await db.connect();
  
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

// Database health check
export const checkConnection = async () => {
  try {
    const client = await db.connect();
    await client.query('SELECT NOW()');
    client.release();
    return true;
  } catch (error) {
    logger.error('Database connection check failed:', error);
    return false;
  }
};

// Graceful shutdown
export const closeConnection = async () => {
  try {
    await db.end();
    logger.info('Database connection pool closed');
  } catch (error) {
    logger.error('Error closing database connection pool:', error);
  }
};

// Set up schema search path for propchain
db.on('connect', async (client) => {
  try {
    await client.query('SET search_path TO propchain, public');
  } catch (error) {
    logger.error('Failed to set search path:', error);
  }
});

export default db;