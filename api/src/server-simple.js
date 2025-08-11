// Simplified server for faster startup during development
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Basic middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3001'],
  credentials: true
}));
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'propchain-api-simple',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0'
  });
});

// API info endpoint
app.get('/api/v1/info', (req, res) => {
  res.json({
    name: 'Property Upkeep Records API (Simplified)',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Auth endpoints (simplified mock)
app.post('/api/v1/auth/login', (req, res) => {
  const { email, password } = req.body;
  
  // Simple mock auth
  if (email && password) {
    res.json({
      user: {
        id: '770e8400-e29b-41d4-a716-446655440000',
        email,
        firstName: 'Demo',
        lastName: 'User',
        organizationId: '660e8400-e29b-41d4-a716-446655440000',
        organizationName: 'Demo Organization',
        role: 'admin',
        permissions: ['*']
      },
      token: 'demo-jwt-token-123456789',
      expiresAt: new Date(Date.now() + 3600000).toISOString()
    });
  } else {
    res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid credentials'
    });
  }
});

app.get('/api/v1/auth/profile', (req, res) => {
  res.json({
    user: {
      id: '770e8400-e29b-41d4-a716-446655440000',
      email: 'demo@example.com',
      firstName: 'Demo',
      lastName: 'User',
      organizationId: '660e8400-e29b-41d4-a716-446655440000',
      organizationName: 'Demo Organization',
      role: 'admin',
      permissions: ['*']
    }
  });
});

app.post('/api/v1/auth/logout', (req, res) => {
  res.json({ message: 'Logged out successfully' });
});

// Mock endpoints
app.get('/api/v1/organizations', (req, res) => {
  res.json({ organizations: [] });
});

app.get('/api/v1/properties', (req, res) => {
  res.json({ properties: [] });
});

app.get('/api/v1/work-logs', (req, res) => {
  res.json({ workLogs: [] });
});

app.get('/api/v1/documents', (req, res) => {
  res.json({ documents: [] });
});

app.get('/api/v1/invoices', (req, res) => {
  res.json({ invoices: [] });
});

app.get('/api/v1/reports/work-summary', (req, res) => {
  res.json({
    summary: {
      totalJobs: 0,
      completedJobs: 0,
      pendingJobs: 0
    }
  });
});

// Metrics endpoint (simple)
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(`
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total 1

# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 1
http_request_duration_seconds_sum 0.05
http_request_duration_seconds_count 1
`);
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
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: 'Something went wrong',
    timestamp: new Date().toISOString()
  });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Property Upkeep Records API (Simplified) running on port ${PORT}`);
  console.log(`📚 Health Check: http://localhost:${PORT}/health`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

export default app;