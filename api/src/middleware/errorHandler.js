import { logger } from '../utils/logger.js';

// Custom error classes
export class AppError extends Error {
  constructor(message, statusCode = 500, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.name = this.constructor.name;
    
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message, details = null) {
    super(message, 400);
    this.details = details;
  }
}

export class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized access') {
    super(message, 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Access forbidden') {
    super(message, 403);
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Resource conflict') {
    super(message, 409);
  }
}

// Error handler middleware
export const errorHandler = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;

  // Log error details
  const errorContext = {
    error: {
      name: err.name,
      message: err.message,
      stack: err.stack
    },
    request: {
      method: req.method,
      url: req.originalUrl,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      userId: req.user?.id,
      organizationId: req.user?.organizationId
    }
  };

  // Log based on error severity
  if (err.statusCode >= 500) {
    logger.error('Server error occurred', errorContext);
  } else if (err.statusCode >= 400) {
    logger.warn('Client error occurred', errorContext);
  } else {
    logger.info('Request completed with error', errorContext);
  }

  // Database connection errors
  if (err.code === 'ECONNREFUSED' || err.code === 'ENOTFOUND') {
    error = new AppError('Database connection failed', 503, false);
  }

  // PostgreSQL specific errors
  if (err.code) {
    switch (err.code) {
      case '23505': // Unique violation
        error = new ConflictError('Resource already exists');
        break;
      case '23503': // Foreign key violation
        error = new ValidationError('Referenced resource does not exist');
        break;
      case '23514': // Check constraint violation
        error = new ValidationError('Data validation failed');
        break;
      case '42P01': // Table doesn't exist
        error = new AppError('Database schema error', 500, false);
        break;
      case '42703': // Column doesn't exist
        error = new AppError('Database schema error', 500, false);
        break;
    }
  }

  // JWT specific errors
  if (err.name === 'JsonWebTokenError') {
    error = new UnauthorizedError('Invalid token');
  } else if (err.name === 'TokenExpiredError') {
    error = new UnauthorizedError('Token expired');
  }

  // Validation errors (from Joi or similar)
  if (err.name === 'ValidationError') {
    const details = err.details?.map(detail => ({
      field: detail.path?.join('.'),
      message: detail.message,
      value: detail.context?.value
    }));
    error = new ValidationError('Validation failed', details);
  }

  // Multer file upload errors
  if (err.code === 'LIMIT_FILE_SIZE') {
    error = new ValidationError('File too large');
  } else if (err.code === 'LIMIT_FILE_COUNT') {
    error = new ValidationError('Too many files');
  } else if (err.code === 'LIMIT_UNEXPECTED_FILE') {
    error = new ValidationError('Unexpected file field');
  }

  // Rate limiting errors
  if (err.status === 429) {
    error = new AppError('Too many requests', 429);
  }

  // Default to 500 server error
  if (!error.statusCode) {
    error = new AppError('Internal server error', 500, false);
  }

  // Prepare error response
  const errorResponse = {
    error: error.name || 'Error',
    message: error.message || 'An error occurred',
    timestamp: new Date().toISOString(),
    path: req.originalUrl,
    method: req.method
  };

  // Add details for validation errors
  if (error instanceof ValidationError && error.details) {
    errorResponse.details = error.details;
  }

  // Add stack trace in development
  if (process.env.NODE_ENV === 'development') {
    errorResponse.stack = err.stack;
  }

  // Add request ID if available
  if (req.requestId) {
    errorResponse.requestId = req.requestId;
  }

  // Send error response
  res.status(error.statusCode).json(errorResponse);
};

// Async error handler wrapper
export const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// 404 Not Found handler
export const notFoundHandler = (req, res, next) => {
  const error = new NotFoundError(`Route ${req.originalUrl} not found`);
  next(error);
};

// Validation middleware factory
export const validate = (schema, source = 'body') => {
  return (req, res, next) => {
    const data = req[source];
    const { error, value } = schema.validate(data, {
      abortEarly: false,
      allowUnknown: false,
      stripUnknown: true
    });

    if (error) {
      const details = error.details.map(detail => ({
        field: detail.path?.join('.'),
        message: detail.message,
        value: detail.context?.value
      }));
      
      return next(new ValidationError('Validation failed', details));
    }

    // Replace request data with validated/sanitized data
    req[source] = value;
    next();
  };
};

export default {
  AppError,
  ValidationError,
  NotFoundError,
  UnauthorizedError,
  ForbiddenError,
  ConflictError,
  errorHandler,
  asyncHandler,
  notFoundHandler,
  validate
};