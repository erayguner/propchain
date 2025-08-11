import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import Joi from 'joi';
import { v4 as uuidv4 } from 'uuid';
import winston from 'winston';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3002;
const JWT_SECRET = process.env.JWT_SECRET || 'dev_jwt_secret_key_very_long_and_secure_123456789';

// Logger setup
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Mock user database (in-memory for development)
const mockUsers = [
  {
    id: '770e8400-e29b-41d4-a716-446655440000',
    email: 'admin@acme-property.com',
    password: 'password123', // In production, this would be hashed
    firstName: 'Sarah',
    lastName: 'Johnson',
    organizationId: '660e8400-e29b-41d4-a716-446655440000',
    organizationName: 'Acme Property Management',
    role: 'org_admin',
    permissions: ['org.*'],
    isActive: true
  },
  {
    id: '770e8400-e29b-41d4-a716-446655440001',
    email: 'manager@acme-property.com',
    password: 'password123',
    firstName: 'James',
    lastName: 'Smith',
    organizationId: '660e8400-e29b-41d4-a716-446655440000',
    organizationName: 'Acme Property Management',
    role: 'property_manager',
    permissions: ['property.*', 'work_log.*', 'document.*'],
    isActive: true
  },
  {
    id: '770e8400-e29b-41d4-a716-446655440002',
    email: 'contractor1@example.com',
    password: 'password123',
    firstName: 'Mike',
    lastName: 'Wilson',
    organizationId: '660e8400-e29b-41d4-a716-446655440000',
    organizationName: 'Acme Property Management',
    role: 'contractor',
    permissions: ['work_log.view', 'work_log.update', 'document.create'],
    isActive: true
  },
  {
    id: '770e8400-e29b-41d4-a716-446655440006',
    email: 'tenant@example.com',
    password: 'password123',
    firstName: 'John',
    lastName: 'Miller',
    organizationId: '660e8400-e29b-41d4-a716-446655440002',
    organizationName: 'City Living Properties',
    role: 'tenant',
    permissions: ['property.view', 'work_log.view'],
    isActive: true
  },
  {
    id: '770e8400-e29b-41d4-a716-446655440007',
    email: 'auditor@compliance.com',
    password: 'password123',
    firstName: 'Rachel',
    lastName: 'Green',
    organizationId: '660e8400-e29b-41d4-a716-446655440000',
    organizationName: 'Acme Property Management',
    role: 'auditor',
    permissions: ['*.view', 'audit.*'],
    isActive: true
  }
];

// Mock sessions store (in production, use Redis or database)
const activeSessions = new Map();

// Rate limiting
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each IP to 10 auth attempts per windowMs
  message: {
    error: 'Too many authentication attempts, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
});

// Middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3001'],
  credentials: true
}));
app.use(morgan('combined'));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Validation schemas
const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(6).required()
});

const refreshSchema = Joi.object({
  refreshToken: Joi.string().required()
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'auth-mock',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    activeUsers: activeSessions.size
  });
});

// Service info
app.get('/api/v1/auth/info', (req, res) => {
  res.json({
    service: 'Property Upkeep Records - Authentication Service (Mock)',
    version: '1.0.0',
    environment: 'development',
    features: {
      login: true,
      refresh: true,
      logout: true,
      profile: true,
      multiTenant: true
    },
    mockUsers: mockUsers.map(user => ({
      email: user.email,
      role: user.role,
      organization: user.organizationName
    }))
  });
});

// Login endpoint
app.post('/api/v1/auth/login', authLimiter, async (req, res) => {
  try {
    // Validate request
    const { error, value } = loginSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Validation Error',
        message: error.details[0].message,
        timestamp: new Date().toISOString()
      });
    }

    const { email, password } = value;

    // Find user (case insensitive email)
    const user = mockUsers.find(u => 
      u.email.toLowerCase() === email.toLowerCase() && u.isActive
    );

    if (!user) {
      logger.warn('Login attempt with invalid email', { email, ip: req.ip });
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid email or password',
        timestamp: new Date().toISOString()
      });
    }

    // Check password (in development, we accept any password for mock users)
    // In production: const isValid = await bcrypt.compare(password, user.hashedPassword);
    const isValid = user.password === password;

    if (!isValid) {
      logger.warn('Login attempt with invalid password', { userId: user.id, email, ip: req.ip });
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid email or password',
        timestamp: new Date().toISOString()
      });
    }

    // Generate tokens
    const sessionId = uuidv4();
    const tokenPayload = {
      userId: user.id,
      email: user.email,
      organizationId: user.organizationId,
      role: user.role,
      sessionId,
      iat: Math.floor(Date.now() / 1000)
    };

    const accessToken = jwt.sign(tokenPayload, JWT_SECRET, {
      expiresIn: '1h',
      issuer: 'propchain-auth-mock',
      audience: 'propchain-app'
    });

    const refreshToken = jwt.sign(
      { userId: user.id, sessionId, type: 'refresh' },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    // Store session
    activeSessions.set(sessionId, {
      userId: user.id,
      createdAt: Date.now(),
      lastActivity: Date.now(),
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    // Clean up old sessions (simple cleanup)
    const now = Date.now();
    const oneWeek = 7 * 24 * 60 * 60 * 1000;
    for (const [sid, session] of activeSessions) {
      if (now - session.createdAt > oneWeek) {
        activeSessions.delete(sid);
      }
    }

    const userData = {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      organizationId: user.organizationId,
      organizationName: user.organizationName,
      role: user.role,
      permissions: user.permissions
    };

    logger.info('User logged in successfully', {
      userId: user.id,
      email: user.email,
      organizationId: user.organizationId,
      sessionId,
      ip: req.ip
    });

    res.json({
      user: userData,
      token: accessToken,
      refreshToken,
      expiresAt: new Date(Date.now() + 3600000).toISOString(),
      sessionId
    });

  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authentication service temporarily unavailable',
      timestamp: new Date().toISOString()
    });
  }
});

// Refresh token endpoint
app.post('/api/v1/auth/refresh', async (req, res) => {
  try {
    const { error, value } = refreshSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Validation Error',
        message: error.details[0].message,
        timestamp: new Date().toISOString()
      });
    }

    const { refreshToken } = value;

    // Verify refresh token
    let decoded;
    try {
      decoded = jwt.verify(refreshToken, JWT_SECRET);
    } catch (jwtError) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired refresh token',
        timestamp: new Date().toISOString()
      });
    }

    if (decoded.type !== 'refresh') {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid token type',
        timestamp: new Date().toISOString()
      });
    }

    // Check if session is still active
    const session = activeSessions.get(decoded.sessionId);
    if (!session || session.userId !== decoded.userId) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Session expired or invalid',
        timestamp: new Date().toISOString()
      });
    }

    // Find user
    const user = mockUsers.find(u => u.id === decoded.userId && u.isActive);
    if (!user) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'User not found or inactive',
        timestamp: new Date().toISOString()
      });
    }

    // Generate new access token
    const tokenPayload = {
      userId: user.id,
      email: user.email,
      organizationId: user.organizationId,
      role: user.role,
      sessionId: decoded.sessionId,
      iat: Math.floor(Date.now() / 1000)
    };

    const newAccessToken = jwt.sign(tokenPayload, JWT_SECRET, {
      expiresIn: '1h',
      issuer: 'propchain-auth-mock',
      audience: 'propchain-app'
    });

    // Update session activity
    session.lastActivity = Date.now();
    activeSessions.set(decoded.sessionId, session);

    logger.info('Token refreshed successfully', {
      userId: user.id,
      sessionId: decoded.sessionId,
      ip: req.ip
    });

    res.json({
      token: newAccessToken,
      expiresAt: new Date(Date.now() + 3600000).toISOString()
    });

  } catch (error) {
    logger.error('Token refresh error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authentication service temporarily unavailable',
      timestamp: new Date().toISOString()
    });
  }
});

// Logout endpoint
app.post('/api/v1/auth/logout', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      
      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        
        // Remove session
        if (decoded.sessionId) {
          activeSessions.delete(decoded.sessionId);
          logger.info('User logged out successfully', {
            userId: decoded.userId,
            sessionId: decoded.sessionId,
            ip: req.ip
          });
        }
        
      } catch (jwtError) {
        // Token might be invalid, but we still want to allow logout
        logger.warn('Logout attempt with invalid token:', jwtError.message);
      }
    }

    res.json({
      message: 'Logged out successfully',
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('Logout error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authentication service temporarily unavailable',
      timestamp: new Date().toISOString()
    });
  }
});

// Profile endpoint
app.get('/api/v1/auth/profile', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No authorization token provided',
        timestamp: new Date().toISOString()
      });
    }

    const token = authHeader.substring(7);
    let decoded;

    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (jwtError) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired token',
        timestamp: new Date().toISOString()
      });
    }

    // Find user
    const user = mockUsers.find(u => u.id === decoded.userId && u.isActive);
    if (!user) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'User not found or inactive',
        timestamp: new Date().toISOString()
      });
    }

    // Update session activity if session exists
    if (decoded.sessionId && activeSessions.has(decoded.sessionId)) {
      const session = activeSessions.get(decoded.sessionId);
      session.lastActivity = Date.now();
      activeSessions.set(decoded.sessionId, session);
    }

    const userData = {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      organizationId: user.organizationId,
      organizationName: user.organizationName,
      role: user.role,
      permissions: user.permissions,
      sessionId: decoded.sessionId
    };

    res.json({
      user: userData
    });

  } catch (error) {
    logger.error('Profile fetch error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authentication service temporarily unavailable',
      timestamp: new Date().toISOString()
    });
  }
});

// Sessions endpoint (for debugging)
app.get('/api/v1/auth/sessions', (req, res) => {
  if (process.env.NODE_ENV !== 'development') {
    return res.status(404).json({ error: 'Not Found' });
  }

  const sessions = Array.from(activeSessions.entries()).map(([id, session]) => ({
    sessionId: id,
    userId: session.userId,
    createdAt: new Date(session.createdAt).toISOString(),
    lastActivity: new Date(session.lastActivity).toISOString(),
    ip: session.ip
  }));

  res.json({
    activeSessions: sessions.length,
    sessions
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `The requested endpoint ${req.originalUrl} was not found.`,
    timestamp: new Date().toISOString()
  });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: 'Authentication service error',
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received. Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received. Shutting down gracefully...');
  process.exit(0);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  logger.info(`🔐 Mock Authentication Service running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`Available mock users: ${mockUsers.length}`);
  mockUsers.forEach(user => {
    logger.info(`  - ${user.email} (${user.role}) - Organization: ${user.organizationName}`);
  });
});

export default app;