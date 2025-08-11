import Redis from 'redis';
import { logger } from './logger.js';

// Redis configuration
const redisConfig = {
  url: process.env.REDIS_URL || 'redis://localhost:6379',
  retryDelayOnFailover: 100,
  enableReadyCheck: true,
  maxRetriesPerRequest: 3,
  lazyConnect: true
};

// Create Redis client
export const redis = Redis.createClient(redisConfig);

// Handle Redis events
redis.on('connect', () => {
  logger.info('Redis client connected');
});

redis.on('ready', () => {
  logger.info('Redis client ready');
});

redis.on('error', (err) => {
  logger.error('Redis client error:', err);
});

redis.on('end', () => {
  logger.info('Redis client connection ended');
});

redis.on('reconnecting', () => {
  logger.info('Redis client reconnecting');
});

// Connect to Redis
export const connectRedis = async () => {
  try {
    await redis.connect();
    logger.info('Connected to Redis');
  } catch (error) {
    logger.error('Failed to connect to Redis:', error);
    throw error;
  }
};

// Session management helpers
export const sessionManager = {
  // Store user session
  async setSession(userId, sessionData, ttl = 3600) {
    const key = `session:${userId}`;
    try {
      await redis.setEx(key, ttl, JSON.stringify(sessionData));
      logger.debug('Session stored', { userId, ttl });
    } catch (error) {
      logger.error('Failed to store session:', error);
      throw error;
    }
  },

  // Get user session
  async getSession(userId) {
    const key = `session:${userId}`;
    try {
      const session = await redis.get(key);
      if (session) {
        return JSON.parse(session);
      }
      return null;
    } catch (error) {
      logger.error('Failed to get session:', error);
      throw error;
    }
  },

  // Delete user session
  async deleteSession(userId) {
    const key = `session:${userId}`;
    try {
      await redis.del(key);
      logger.debug('Session deleted', { userId });
    } catch (error) {
      logger.error('Failed to delete session:', error);
      throw error;
    }
  },

  // Extend session TTL
  async extendSession(userId, ttl = 3600) {
    const key = `session:${userId}`;
    try {
      await redis.expire(key, ttl);
      logger.debug('Session extended', { userId, ttl });
    } catch (error) {
      logger.error('Failed to extend session:', error);
      throw error;
    }
  }
};

// Cache helpers
export const cache = {
  // Set cache with TTL
  async set(key, value, ttl = 300) {
    try {
      const serializedValue = JSON.stringify(value);
      await redis.setEx(key, ttl, serializedValue);
      logger.debug('Cache set', { key, ttl });
    } catch (error) {
      logger.error('Failed to set cache:', error);
      throw error;
    }
  },

  // Get cache
  async get(key) {
    try {
      const value = await redis.get(key);
      if (value) {
        return JSON.parse(value);
      }
      return null;
    } catch (error) {
      logger.error('Failed to get cache:', error);
      throw error;
    }
  },

  // Delete cache
  async del(key) {
    try {
      await redis.del(key);
      logger.debug('Cache deleted', { key });
    } catch (error) {
      logger.error('Failed to delete cache:', error);
      throw error;
    }
  },

  // Invalidate pattern
  async invalidatePattern(pattern) {
    try {
      const keys = await redis.keys(pattern);
      if (keys.length > 0) {
        await redis.del(keys);
        logger.debug('Cache pattern invalidated', { pattern, count: keys.length });
      }
    } catch (error) {
      logger.error('Failed to invalidate cache pattern:', error);
      throw error;
    }
  }
};

// Rate limiting helpers
export const rateLimiter = {
  // Check rate limit
  async checkLimit(key, limit, window) {
    try {
      const current = await redis.incr(key);
      
      if (current === 1) {
        // First request, set expiry
        await redis.expire(key, window);
      }
      
      return {
        count: current,
        remaining: Math.max(0, limit - current),
        resetTime: Date.now() + (window * 1000),
        allowed: current <= limit
      };
    } catch (error) {
      logger.error('Rate limit check failed:', error);
      // On error, allow the request
      return {
        count: 0,
        remaining: limit,
        resetTime: Date.now() + (window * 1000),
        allowed: true
      };
    }
  }
};

// Pub/Sub helpers for real-time features
export const pubsub = {
  // Publish message
  async publish(channel, message) {
    try {
      const serializedMessage = JSON.stringify({
        ...message,
        timestamp: Date.now()
      });
      await redis.publish(channel, serializedMessage);
      logger.debug('Message published', { channel, message });
    } catch (error) {
      logger.error('Failed to publish message:', error);
      throw error;
    }
  },

  // Subscribe to channel
  async subscribe(channel, callback) {
    try {
      const subscriber = redis.duplicate();
      await subscriber.connect();
      
      await subscriber.subscribe(channel, (message) => {
        try {
          const parsedMessage = JSON.parse(message);
          callback(parsedMessage);
        } catch (error) {
          logger.error('Failed to parse subscription message:', error);
        }
      });
      
      logger.info('Subscribed to channel', { channel });
      return subscriber;
    } catch (error) {
      logger.error('Failed to subscribe to channel:', error);
      throw error;
    }
  }
};

// Graceful shutdown
export const closeRedis = async () => {
  try {
    await redis.quit();
    logger.info('Redis connection closed');
  } catch (error) {
    logger.error('Error closing Redis connection:', error);
  }
};

// Initialize Redis connection if not already connected
if (!redis.isOpen) {
  connectRedis().catch((error) => {
    logger.error('Failed to initialize Redis connection:', error);
    process.exit(1);
  });
}

export default redis;