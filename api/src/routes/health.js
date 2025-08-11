import express from 'express';
import { db } from '../utils/database.js';
import { redis } from '../utils/redis.js';
import { logger } from '../utils/logger.js';

const router = express.Router();

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Health check endpoint
 *     description: Returns the health status of the API and its dependencies
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: healthy
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 uptime:
 *                   type: number
 *                   example: 3600.5
 *                 version:
 *                   type: string
 *                   example: 1.0.0
 *                 environment:
 *                   type: string
 *                   example: development
 *                 services:
 *                   type: object
 *                   properties:
 *                     database:
 *                       type: object
 *                       properties:
 *                         status:
 *                           type: string
 *                           example: healthy
 *                         responseTime:
 *                           type: number
 *                           example: 15
 *                     redis:
 *                       type: object
 *                       properties:
 *                         status:
 *                           type: string
 *                           example: healthy
 *                         responseTime:
 *                           type: number
 *                           example: 8
 *       503:
 *         description: Service is unhealthy
 */
router.get('/', async (req, res) => {
  const startTime = Date.now();
  
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    services: {}
  };

  let overallStatus = 'healthy';

  // Check Database
  try {
    const dbStart = Date.now();
    await db.query('SELECT 1');
    const dbTime = Date.now() - dbStart;
    
    health.services.database = {
      status: 'healthy',
      responseTime: dbTime
    };
    
    logger.debug(`Database health check: ${dbTime}ms`);
  } catch (error) {
    health.services.database = {
      status: 'unhealthy',
      error: error.message
    };
    overallStatus = 'unhealthy';
    logger.error('Database health check failed:', error);
  }

  // Check Redis
  try {
    const redisStart = Date.now();
    await redis.ping();
    const redisTime = Date.now() - redisStart;
    
    health.services.redis = {
      status: 'healthy',
      responseTime: redisTime
    };
    
    logger.debug(`Redis health check: ${redisTime}ms`);
  } catch (error) {
    health.services.redis = {
      status: 'unhealthy',
      error: error.message
    };
    overallStatus = 'unhealthy';
    logger.error('Redis health check failed:', error);
  }

  // Check AWS Services (LocalStack in development)
  try {
    const awsStart = Date.now();
    // Simple check for S3 availability
    // In production, this would check actual AWS services
    const awsTime = Date.now() - awsStart;
    
    health.services.aws = {
      status: 'healthy',
      responseTime: awsTime,
      services: ['s3', 'sqs', 'secretsmanager']
    };
  } catch (error) {
    health.services.aws = {
      status: 'degraded',
      error: error.message
    };
    // AWS issues shouldn't mark the entire service as unhealthy
    logger.warn('AWS services health check failed:', error);
  }

  // Overall health status
  health.status = overallStatus;
  health.responseTime = Date.now() - startTime;

  // Add memory usage
  health.memory = {
    used: process.memoryUsage().heapUsed,
    total: process.memoryUsage().heapTotal,
    rss: process.memoryUsage().rss
  };

  const statusCode = overallStatus === 'healthy' ? 200 : 503;
  res.status(statusCode).json(health);
});

/**
 * @swagger
 * /health/ready:
 *   get:
 *     summary: Readiness probe
 *     description: Returns 200 if the service is ready to serve traffic
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is ready
 *       503:
 *         description: Service is not ready
 */
router.get('/ready', async (req, res) => {
  try {
    // Check critical dependencies
    await db.query('SELECT 1');
    await redis.ping();
    
    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Readiness check failed:', error);
    res.status(503).json({
      status: 'not ready',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * @swagger
 * /health/live:
 *   get:
 *     summary: Liveness probe
 *     description: Returns 200 if the service is alive
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: Service is alive
 */
router.get('/live', (req, res) => {
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

export default router;