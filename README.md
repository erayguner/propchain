# 🏠 Property Upkeep Records - Local Development Environment

A comprehensive system for tracking property maintenance, repairs, and improvements with full local development setup.

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Node.js 18+ (for local development)
- Git

### 1. Clone and Setup
```bash
git clone <repository-url>
cd propchain
cp .env.example .env.local
```

### 2. Start Everything
```bash
make setup-local
```

This single command will:
- Build all containers
- Start all services
- Configure LocalStack resources
- Seed the database with test data
- Set up monitoring stack

### 3. Access the System

| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | http://localhost:3001 | See mock users below |
| **API** | http://localhost:3000 | - |
| **API Docs** | http://localhost:3000/api/docs | - |
| **Grafana** | http://localhost:3003 | admin/admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Database Admin** | http://localhost:8080 | Server: postgres, User: propchain, Password: dev_password_123 |
| **MailCatcher** | http://localhost:1080 | - |
| **MinIO Console** | http://localhost:9001 | minioadmin/minioadmin123 |

## 👥 Mock Users for Testing

| Email | Password | Role | Organization |
|-------|----------|------|-------------|
| admin@acme-property.com | password123 | Admin | Acme Property Management |
| manager@acme-property.com | password123 | Property Manager | Acme Property Management |
| contractor1@example.com | password123 | Contractor | Acme Property Management |
| tenant@example.com | password123 | Tenant | City Living Properties |
| auditor@compliance.com | password123 | Auditor | Cross-organization |

## 🛠 Development Commands

```bash
# Start the environment
make up

# Stop everything
make down

# View logs
make logs

# Reset database with fresh data
make reset-db

# Run tests
make test

# Open database shell
make shell-db

# Open API container shell
make shell-api

# Check service health
make health

# Full environment reset
make full-reset
```

## 📊 System Architecture

### Services Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   API Server    │    │   Auth Mock     │
│   (React)       │    │   (Node.js)     │    │   (JWT)         │
│   Port: 3001    │    │   Port: 3000    │    │   Port: 3002    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌───────────────────────────────────────────────────────┐
         │                NGINX Reverse Proxy                    │
         │                    Port: 80                           │
         └───────────────────────────────────────────────────────┘
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │     Redis       │    │   LocalStack    │
│   Port: 5432    │    │   Port: 6379    │    │   Port: 4566    │
│   (Database)    │    │   (Sessions)    │    │   (AWS Mock)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Features
- ✅ **Multi-tenant Architecture** - Complete organization isolation
- ✅ **Real-time Monitoring** - Prometheus + Grafana dashboards
- ✅ **File Upload & Storage** - MinIO S3-compatible storage
- ✅ **Background Processing** - SQS + worker processes
- ✅ **Authentication & Authorization** - JWT + RBAC
- ✅ **Email Testing** - MailCatcher for development
- ✅ **API Documentation** - Swagger/OpenAPI integration
- ✅ **Database Management** - Adminer web interface

## 📋 API Endpoints

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Refresh token
- `POST /api/v1/auth/logout` - User logout
- `GET /api/v1/auth/profile` - Get user profile

### Organizations
- `GET /api/v1/organizations` - List organizations
- `GET /api/v1/organizations/:id` - Get organization details
- `GET /api/v1/organizations/:id/stats` - Get organization statistics

### Properties
- `GET /api/v1/properties` - List properties
- `POST /api/v1/properties` - Create property
- `GET /api/v1/properties/:id` - Get property details
- `PUT /api/v1/properties/:id` - Update property
- `DELETE /api/v1/properties/:id` - Delete property

### Work Logs
- `GET /api/v1/work-logs` - List work logs
- `POST /api/v1/work-logs` - Create work log
- `GET /api/v1/work-logs/:id` - Get work log details
- `PUT /api/v1/work-logs/:id` - Update work log
- `DELETE /api/v1/work-logs/:id` - Delete work log

### Documents
- `GET /api/v1/documents` - List documents
- `POST /api/v1/documents` - Upload document
- `GET /api/v1/documents/:id` - Get document details
- `DELETE /api/v1/documents/:id` - Delete document

### Reports
- `GET /api/v1/reports/work-summary` - Work summary report
- `GET /api/v1/reports/costs` - Cost analysis report
- `GET /api/v1/reports/maintenance-schedule` - Maintenance schedule

## 🗄 Database Schema

The system uses PostgreSQL with the following main entities:

```sql
-- Core entities
organizations        -- Multi-tenant isolation
users               -- User accounts
roles               -- RBAC system
properties          -- Properties to manage
assets              -- Equipment/systems (HVAC, lifts, etc.)
work_logs           -- Completed maintenance work
documents           -- Photos, PDFs, certificates
invoices            -- Financial records
audit_events        -- Immutable audit trail
notifications       -- Email/SMS notifications
```

### Sample Data
The development environment comes with:
- 3 organizations with different setups
- 8 users across different roles
- 6 properties of various types
- 15+ completed work logs
- Sample documents and invoices
- Comprehensive audit trail

## 🔐 Security Features

### Authentication & Authorization
- JWT-based authentication
- Role-based access control (RBAC)
- Multi-tenant data isolation
- API key support for integrations
- Session management with Redis

### Security Middleware
- Helmet.js security headers
- CORS configuration
- Rate limiting
- Input validation with Joi
- SQL injection prevention
- File upload security

## 📈 Monitoring & Observability

### Metrics Collection
- **Prometheus** scrapes metrics from all services
- **Custom business metrics** (work logs, documents, costs)
- **Infrastructure metrics** (CPU, memory, database)
- **Application metrics** (response times, error rates)

### Dashboards
- **API Performance** - Response times, throughput, errors
- **Business Metrics** - Work completion rates, costs
- **Infrastructure** - Service health, resource usage
- **Database** - Connection pools, query performance

### Alerting
- High error rates (>5%)
- Slow response times (>2s p95)
- Service availability
- Resource exhaustion
- Business anomalies

## 🧪 Testing

### Available Test Suites
```bash
# Unit tests
make test

# API integration tests  
make test-api

# Load testing
make load-test

# Benchmark tests
make benchmark
```

### Test Data
- Comprehensive seed data with realistic scenarios
- Multi-organization test cases
- Different user roles and permissions
- Sample work logs across different categories
- File upload testing with various formats

## 🔧 Configuration

### Environment Variables
Copy `.env.example` to `.env.local` and customize:

```bash
# Database
DATABASE_URL=postgresql://propchain:dev_password_123@localhost:5432/propchain_dev

# Redis
REDIS_URL=redis://:dev_redis_123@localhost:6379

# JWT
JWT_SECRET=dev_jwt_secret_key_very_long_and_secure_123456789

# File uploads
MAX_FILE_SIZE=10485760
ALLOWED_FILE_TYPES=image/jpeg,image/png,image/webp,application/pdf

# Feature flags
FEATURE_WEBHOOKS=true
FEATURE_ANALYTICS=true
FEATURE_REAL_TIME=true
```

## 🐛 Troubleshooting

### Common Issues

**Services not starting:**
```bash
# Check Docker resources
docker system df
docker system prune -f

# Check logs
make logs
```

**Database connection issues:**
```bash
# Reset database
make reset-db

# Check database status
make health
```

**Port conflicts:**
```bash
# Check what's using ports
lsof -i :3000
lsof -i :5432

# Kill conflicting processes
sudo kill -9 <PID>
```

### Debug Mode
Enable detailed logging:
```bash
export LOG_LEVEL=debug
make up
```

## 🚀 Production Deployment

This development environment is designed to be production-ready:

1. **Containerized** - All services use Docker
2. **Infrastructure as Code** - Terraform modules included
3. **Monitoring** - Comprehensive metrics and alerting
4. **Security** - Production-grade authentication and authorization
5. **Scalability** - Horizontal scaling ready
6. **Backup** - Database backup strategies included

See `terraform/` directory for AWS deployment configuration.

## 📚 Additional Resources

- [API Documentation](http://localhost:3000/api/docs) - Interactive Swagger docs
- [Technical Specification](./TECHNICAL_SPECIFICATION.md) - Detailed system design
- [Database Schema](./database_schema.sql) - Complete DDL
- [Runbooks](./RUNBOOKS.md) - Operational procedures

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Ready to build property management software? Start with `make setup-local` and you'll have a full-featured development environment in minutes! 🚀**