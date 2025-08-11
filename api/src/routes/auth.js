import express from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { db } from '../utils/database.js';
import { sessionManager } from '../utils/redis.js';
import { logger } from '../utils/logger.js';
import { asyncHandler, ValidationError, UnauthorizedError } from '../middleware/errorHandler.js';

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'dev_jwt_secret_key_very_long_and_secure_123456789';

/**
 * @swagger
 * /api/v1/auth/login:
 *   post:
 *     summary: User login
 *     description: Authenticate user and return JWT token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: admin@acme-property.com
 *               password:
 *                 type: string
 *                 example: password123
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     email:
 *                       type: string
 *                     firstName:
 *                       type: string
 *                     lastName:
 *                       type: string
 *                     organizationId:
 *                       type: string
 *                     organizationName:
 *                       type: string
 *                     role:
 *                       type: string
 *                 token:
 *                   type: string
 *                 refreshToken:
 *                   type: string
 *                 expiresAt:
 *                   type: string
 *                   format: date-time
 *       401:
 *         description: Invalid credentials
 *       400:
 *         description: Validation error
 */
router.post('/login', asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  
  if (!email || !password) {
    throw new ValidationError('Email and password are required');
  }
  
  // For development, we'll use a simple mock authentication
  // In production, this would verify against actual password hashes
  
  const userQuery = `
    SELECT 
      u.id, u.email, u.first_name, u.last_name, u.is_active,
      uo.organization_id, o.name as organization_name, o.slug as organization_slug,
      r.name as role_name, r.permissions
    FROM users u
    JOIN user_organization_roles uo ON u.id = uo.user_id AND uo.is_active = true
    JOIN organizations o ON uo.organization_id = o.id AND o.is_active = true
    JOIN roles r ON uo.role_id = r.id
    WHERE LOWER(u.email) = LOWER($1) AND u.is_active = true
    ORDER BY uo.created_at ASC
    LIMIT 1
  `;
  
  const result = await db.query(userQuery, [email]);
  
  if (result.rows.length === 0) {
    throw new UnauthorizedError('Invalid email or password');
  }
  
  const user = result.rows[0];
  
  // In development, accept any password for demo users
  // In production, verify password hash: await bcrypt.compare(password, user.password_hash)
  const isValidPassword = true;
  
  if (!isValidPassword) {
    throw new UnauthorizedError('Invalid email or password');
  }
  
  // Generate JWT token
  const tokenPayload = {
    userId: user.id,
    email: user.email,
    organizationId: user.organization_id,
    role: user.role_name,
    iat: Math.floor(Date.now() / 1000)
  };
  
  const token = jwt.sign(tokenPayload, JWT_SECRET, {
    expiresIn: '1h',
    issuer: 'propchain-api',
    audience: 'propchain-app'
  });
  
  const refreshToken = jwt.sign(
    { userId: user.id, type: 'refresh' }, 
    JWT_SECRET, 
    { expiresIn: '7d' }
  );
  
  // Store session
  const sessionData = {
    userId: user.id,
    email: user.email,
    organizationId: user.organization_id,
    role: user.role_name,
    permissions: user.permissions || [],
    lastActivity: Date.now()
  };
  
  await sessionManager.setSession(user.id, sessionData, 3600); // 1 hour
  
  // Update last login
  await db.query(
    'UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = $1',
    [user.id]
  );
  
  const userData = {
    id: user.id,
    email: user.email,
    firstName: user.first_name,
    lastName: user.last_name,
    organizationId: user.organization_id,
    organizationName: user.organization_name,
    organizationSlug: user.organization_slug,
    role: user.role_name,
    permissions: user.permissions || []
  };
  
  logger.info('User logged in successfully', {
    userId: user.id,
    email: user.email,
    organizationId: user.organization_id,
    ip: req.ip
  });
  
  res.json({
    user: userData,
    token,
    refreshToken,
    expiresAt: new Date(Date.now() + 3600000).toISOString() // 1 hour
  });
}));

/**
 * @swagger
 * /api/v1/auth/refresh:
 *   post:
 *     summary: Refresh JWT token
 *     description: Get a new access token using refresh token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Token refreshed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *                 expiresAt:
 *                   type: string
 *                   format: date-time
 *       401:
 *         description: Invalid refresh token
 */
router.post('/refresh', asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  
  if (!refreshToken) {
    throw new ValidationError('Refresh token is required');
  }
  
  try {
    const decoded = jwt.verify(refreshToken, JWT_SECRET);
    
    if (decoded.type !== 'refresh') {
      throw new UnauthorizedError('Invalid token type');
    }
    
    // Get user data
    const userQuery = `
      SELECT 
        u.id, u.email, u.is_active,
        uo.organization_id, r.name as role_name
      FROM users u
      JOIN user_organization_roles uo ON u.id = uo.user_id AND uo.is_active = true
      JOIN roles r ON uo.role_id = r.id
      WHERE u.id = $1 AND u.is_active = true
      LIMIT 1
    `;
    
    const result = await db.query(userQuery, [decoded.userId]);
    
    if (result.rows.length === 0) {
      throw new UnauthorizedError('User not found or inactive');
    }
    
    const user = result.rows[0];
    
    // Generate new access token
    const tokenPayload = {
      userId: user.id,
      email: user.email,
      organizationId: user.organization_id,
      role: user.role_name,
      iat: Math.floor(Date.now() / 1000)
    };
    
    const newToken = jwt.sign(tokenPayload, JWT_SECRET, {
      expiresIn: '1h',
      issuer: 'propchain-api',
      audience: 'propchain-app'
    });
    
    logger.info('Token refreshed successfully', {
      userId: user.id,
      ip: req.ip
    });
    
    res.json({
      token: newToken,
      expiresAt: new Date(Date.now() + 3600000).toISOString()
    });
    
  } catch (error) {
    throw new UnauthorizedError('Invalid or expired refresh token');
  }
}));

/**
 * @swagger
 * /api/v1/auth/logout:
 *   post:
 *     summary: User logout
 *     description: Invalidate user session and tokens
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logout successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Logged out successfully
 *       401:
 *         description: Unauthorized
 */
router.post('/logout', asyncHandler(async (req, res) => {
  const authHeader = req.headers.authorization;
  
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7);
    
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      
      // Clear session
      await sessionManager.deleteSession(decoded.userId);
      
      // In production, you might want to add the token to a blacklist
      
      logger.info('User logged out successfully', {
        userId: decoded.userId,
        ip: req.ip
      });
      
    } catch (error) {
      // Token might be invalid, but we still want to allow logout
      logger.warn('Logout attempt with invalid token:', error.message);
    }
  }
  
  res.json({
    message: 'Logged out successfully'
  });
}));

/**
 * @swagger
 * /api/v1/auth/profile:
 *   get:
 *     summary: Get current user profile
 *     description: Retrieve the authenticated user's profile information
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     email:
 *                       type: string
 *                     firstName:
 *                       type: string
 *                     lastName:
 *                       type: string
 *                     phone:
 *                       type: string
 *                     organizationId:
 *                       type: string
 *                     organizationName:
 *                       type: string
 *                     role:
 *                       type: string
 *                     permissions:
 *                       type: array
 *                       items:
 *                         type: string
 *                     preferences:
 *                       type: object
 *                     lastLoginAt:
 *                       type: string
 *                       format: date-time
 *       401:
 *         description: Unauthorized
 */
router.get('/profile', asyncHandler(async (req, res) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new UnauthorizedError('No authorization token provided');
  }
  
  const token = authHeader.substring(7);
  let decoded;
  
  try {
    decoded = jwt.verify(token, JWT_SECRET);
  } catch (error) {
    throw new UnauthorizedError('Invalid or expired token');
  }
  
  const userQuery = `
    SELECT 
      u.id, u.email, u.first_name, u.last_name, u.phone, 
      u.preferences, u.last_login_at, u.created_at,
      uo.organization_id, o.name as organization_name, o.slug as organization_slug,
      r.name as role_name, r.permissions, r.display_name as role_display_name
    FROM users u
    JOIN user_organization_roles uo ON u.id = uo.user_id AND uo.is_active = true
    JOIN organizations o ON uo.organization_id = o.id AND o.is_active = true
    JOIN roles r ON uo.role_id = r.id
    WHERE u.id = $1 AND u.is_active = true
    ORDER BY uo.created_at ASC
    LIMIT 1
  `;
  
  const result = await db.query(userQuery, [decoded.userId]);
  
  if (result.rows.length === 0) {
    throw new UnauthorizedError('User not found or inactive');
  }
  
  const user = result.rows[0];
  
  const userData = {
    id: user.id,
    email: user.email,
    firstName: user.first_name,
    lastName: user.last_name,
    phone: user.phone,
    organizationId: user.organization_id,
    organizationName: user.organization_name,
    organizationSlug: user.organization_slug,
    role: user.role_name,
    roleDisplayName: user.role_display_name,
    permissions: user.permissions || [],
    preferences: user.preferences || {},
    lastLoginAt: user.last_login_at,
    createdAt: user.created_at
  };
  
  res.json({
    user: userData
  });
}));

export default router;