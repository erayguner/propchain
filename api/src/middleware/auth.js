import jwt from 'jsonwebtoken';
import { db } from '../utils/database.js';
import { cache } from '../utils/redis.js';
import { logger } from '../utils/logger.js';

const JWT_SECRET = process.env.JWT_SECRET || 'dev_jwt_secret_key_very_long_and_secure_123456789';

// Mock JWT verification for development
export const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No valid authorization token provided'
      });
    }
    
    const token = authHeader.substring(7);
    
    // Verify JWT token
    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (error) {
      logger.warn('Invalid JWT token:', error.message);
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
    }
    
    // Check cache for user data
    const cacheKey = `user:${decoded.userId}`;
    let userData = await cache.get(cacheKey);
    
    if (!userData) {
      // Fetch user data from database
      const userQuery = `
        SELECT 
          u.id, u.email, u.first_name, u.last_name, u.is_active,
          uo.organization_id, o.name as organization_name,
          r.name as role_name, r.permissions
        FROM users u
        JOIN user_organization_roles uo ON u.id = uo.user_id AND uo.is_active = true
        JOIN organizations o ON uo.organization_id = o.id AND o.is_active = true
        JOIN roles r ON uo.role_id = r.id
        WHERE u.id = $1 AND u.is_active = true
      `;
      
      const result = await db.query(userQuery, [decoded.userId]);
      
      if (result.rows.length === 0) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'User not found or inactive'
        });
      }
      
      const user = result.rows[0];
      userData = {
        id: user.id,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        organizationId: user.organization_id,
        organizationName: user.organization_name,
        role: user.role_name,
        permissions: user.permissions || []
      };
      
      // Cache user data for 5 minutes
      await cache.set(cacheKey, userData, 300);
    }
    
    // Add user data to request
    req.user = userData;
    
    // Add organization context
    req.organizationId = userData.organizationId;
    
    logger.debug('User authenticated', {
      userId: userData.id,
      organizationId: userData.organizationId,
      role: userData.role
    });
    
    next();
  } catch (error) {
    logger.error('Authentication middleware error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authentication service temporarily unavailable'
    });
  }
};

// Permission checking middleware
export const requirePermission = (permission) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Authentication required'
      });
    }
    
    const userPermissions = req.user.permissions || [];
    
    // Check if user has the specific permission or wildcard
    const hasPermission = userPermissions.some(p => 
      p === permission || 
      p === '*' || 
      (p.endsWith('*') && permission.startsWith(p.slice(0, -1)))
    );
    
    if (!hasPermission) {
      logger.warn('Permission denied', {
        userId: req.user.id,
        requiredPermission: permission,
        userPermissions
      });
      
      return res.status(403).json({
        error: 'Forbidden',
        message: `Permission '${permission}' required`
      });
    }
    
    next();
  };
};

// Organization context middleware
export const organizationContext = async (req, res, next) => {
  try {
    // Skip if no user (will be handled by auth middleware)
    if (!req.user) {
      return next();
    }
    
    // Organization ID can come from:
    // 1. Route parameters (:orgId)
    // 2. Query parameters (?organizationId=)
    // 3. Request body
    // 4. User's default organization
    const orgId = req.params.orgId || 
                  req.query.organizationId || 
                  req.body.organizationId || 
                  req.user.organizationId;
    
    if (!orgId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Organization context required'
      });
    }
    
    // Verify user has access to this organization
    const accessQuery = `
      SELECT o.id, o.name, o.slug
      FROM organizations o
      JOIN user_organization_roles uo ON o.id = uo.organization_id
      WHERE o.id = $1 AND uo.user_id = $2 AND o.is_active = true AND uo.is_active = true
    `;
    
    const result = await db.query(accessQuery, [orgId, req.user.id]);
    
    if (result.rows.length === 0) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Access denied to this organization'
      });
    }
    
    // Add organization context to request
    req.organization = result.rows[0];
    req.organizationId = orgId;
    
    next();
  } catch (error) {
    logger.error('Organization context middleware error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Unable to verify organization access'
    });
  }
};

// Rate limiting by user
export const userRateLimit = (requests = 100, windowMs = 60000) => {
  return async (req, res, next) => {
    if (!req.user) {
      return next();
    }
    
    try {
      const key = `rate_limit:user:${req.user.id}`;
      const window = Math.floor(windowMs / 1000);
      
      const { count, remaining, resetTime, allowed } = await rateLimiter.checkLimit(key, requests, window);
      
      // Add rate limit headers
      res.set({
        'X-RateLimit-Limit': requests,
        'X-RateLimit-Remaining': remaining,
        'X-RateLimit-Reset': new Date(resetTime).toISOString()
      });
      
      if (!allowed) {
        logger.warn('User rate limit exceeded', {
          userId: req.user.id,
          count,
          limit: requests
        });
        
        return res.status(429).json({
          error: 'Too Many Requests',
          message: 'User rate limit exceeded. Please try again later.',
          retryAfter: Math.ceil((resetTime - Date.now()) / 1000)
        });
      }
      
      next();
    } catch (error) {
      logger.error('User rate limit middleware error:', error);
      // On error, allow the request
      next();
    }
  };
};

// API key authentication (for external integrations)
export const apiKeyAuth = async (req, res, next) => {
  try {
    const apiKey = req.headers['x-api-key'];
    
    if (!apiKey) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'API key required'
      });
    }
    
    // Hash the API key for comparison
    const hashedKey = crypto
      .createHash('sha256')
      .update(apiKey)
      .digest('hex');
    
    const tokenQuery = `
      SELECT at.id, at.permissions, at.organization_id, o.name as organization_name
      FROM api_tokens at
      JOIN organizations o ON at.organization_id = o.id
      WHERE at.token_hash = $1 AND at.is_active = true 
        AND (at.expires_at IS NULL OR at.expires_at > CURRENT_TIMESTAMP)
        AND o.is_active = true
    `;
    
    const result = await db.query(tokenQuery, [hashedKey]);
    
    if (result.rows.length === 0) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired API key'
      });
    }
    
    const token = result.rows[0];
    
    // Update last used timestamp
    await db.query(
      'UPDATE api_tokens SET last_used_at = CURRENT_TIMESTAMP WHERE id = $1',
      [token.id]
    );
    
    // Add API token context to request
    req.apiToken = {
      id: token.id,
      permissions: token.permissions || [],
      organizationId: token.organization_id,
      organizationName: token.organization_name
    };
    
    req.organizationId = token.organization_id;
    
    logger.debug('API key authenticated', {
      tokenId: token.id,
      organizationId: token.organization_id
    });
    
    next();
  } catch (error) {
    logger.error('API key authentication error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authentication service temporarily unavailable'
    });
  }
};

export default {
  authMiddleware,
  requirePermission,
  organizationContext,
  userRateLimit,
  apiKeyAuth
};