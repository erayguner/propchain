# 🧪 Property Upkeep Records - Testing Guide

Complete guide for testing the local development environment with sample data and realistic scenarios.

## 🚀 Quick Testing Setup

### 1. Start the Environment
```bash
# Complete setup (first time)
make setup-local

# Or just start if already set up
make up
```

### 2. Verify All Services
```bash
# Check service health
make health

# View service status
make status
```

Expected output - all services should show as "healthy":
```
Name                    Status    Ports
propchain_postgres      Up        5432->5432
propchain_redis         Up        6379->6379
propchain_api           Up        3000->3000
propchain_frontend      Up        3001->3001
propchain_auth_mock     Up        3002->3002
propchain_nginx         Up        80->80, 443->443
propchain_grafana       Up        3003->3000
propchain_prometheus    Up        9090->9090
```

## 👥 Test User Accounts

| Email | Password | Role | Organization | Use Case |
|-------|----------|------|--------------|----------|
| **admin@acme-property.com** | password123 | Admin | Acme Property Management | Full system access, user management |
| **manager@acme-property.com** | password123 | Property Manager | Acme Property Management | Property and work log management |
| **contractor1@example.com** | password123 | Contractor | Acme Property Management | Work completion and photo uploads |
| **tenant@example.com** | password123 | Tenant | City Living Properties | View-only access to property history |
| **auditor@compliance.com** | password123 | Auditor | Cross-organization | Read-only compliance and reporting |

## 📱 Frontend Testing Scenarios

### Scenario 1: Admin Dashboard Overview
```bash
# 1. Navigate to frontend
open http://localhost:3001

# 2. Login as admin
Email: admin@acme-property.com
Password: password123

# 3. Verify dashboard shows:
- Total properties: 3
- Active work logs: 15+
- Recent notifications
- Cost overview charts
```

### Scenario 2: Property Manager Workflow
```bash
# 1. Login as property manager
Email: manager@acme-property.com
Password: password123

# 2. Test complete workflow:
- View property list (should see 3 properties)
- Click "Riverside Apartments"
- View work history (15+ completed jobs)
- Check asset list (HVAC, lifts, boiler)
- Review maintenance costs and trends
```

### Scenario 3: Contractor Mobile Experience  
```bash
# 1. Login as contractor
Email: contractor1@example.com
Password: password123

# 2. Test mobile-first workflow:
- View assigned work logs
- Update job status to "completed"
- Upload photos (before/after)
- Add completion notes
- Submit for verification
```

## 🔌 API Testing

### Health Checks
```bash
# API health
curl http://localhost:3000/health

# Auth service health  
curl http://localhost:3002/health

# NGINX proxy health
curl http://localhost/health
```

### Authentication Flow
```bash
# 1. Login and get token
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@acme-property.com",
    "password": "password123"
  }'

# Expected response:
{
  "user": {
    "id": "770e8400-e29b-41d4-a716-446655440000",
    "email": "admin@acme-property.com",
    "firstName": "Sarah",
    "lastName": "Johnson",
    "organizationId": "660e8400-e29b-41d4-a716-446655440000",
    "role": "org_admin"
  },
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresAt": "2024-01-15T15:30:00.000Z"
}

# 2. Use token for authenticated requests
TOKEN="eyJhbGciOiJIUzI1NiIs..."

# Get user profile
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/auth/profile
```

### CRUD Operations Testing
```bash
# Set your token from login response
export TOKEN="your_jwt_token_here"

# 1. List properties
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/properties"

# 2. Get specific property
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/properties/880e8400-e29b-41d4-a716-446655440000"

# 3. List work logs for property
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/work-logs?propertyId=880e8400-e29b-41d4-a716-446655440000"

# 4. Create new work log
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Maintenance Work",
    "description": "API testing work log creation",
    "workType": "maintenance",
    "propertyId": "880e8400-e29b-41d4-a716-446655440000",
    "completedAt": "2024-01-15T14:00:00Z",
    "labourHours": 2.5,
    "materialCost": 150.00,
    "labourCost": 125.00
  }' \
  "http://localhost:3000/api/v1/work-logs"
```

### File Upload Testing
```bash
# Upload document to work log
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/test-image.jpg" \
  -F "title=Test Document Upload" \
  -F "description=Testing file upload functionality" \
  -F "documentType=photo" \
  -F "workLogId=bb0e8400-e29b-41d4-a716-446655440000" \
  "http://localhost:3000/api/v1/documents"
```

## 📊 Database Testing

### Direct Database Queries
```bash
# Open database shell
make shell-db

# Test queries in PostgreSQL:
```

```sql
-- Check data loading
SELECT COUNT(*) FROM organizations;  -- Should return 3
SELECT COUNT(*) FROM users;          -- Should return 8  
SELECT COUNT(*) FROM properties;     -- Should return 6
SELECT COUNT(*) FROM work_logs;      -- Should return 15+

-- Test organization isolation
SELECT 
  o.name as organization,
  COUNT(p.id) as properties,
  COUNT(wl.id) as work_logs
FROM organizations o
LEFT JOIN properties p ON o.id = p.organization_id
LEFT JOIN work_logs wl ON o.id = wl.organization_id
GROUP BY o.id, o.name;

-- Test recent activity
SELECT 
  wl.title,
  p.name as property,
  wl.completed_at,
  wl.total_cost
FROM work_logs wl
JOIN properties p ON wl.property_id = p.id
ORDER BY wl.completed_at DESC
LIMIT 10;

-- Test cost analysis
SELECT 
  DATE_TRUNC('month', completed_at) as month,
  COUNT(*) as jobs,
  SUM(total_cost) as total_cost,
  AVG(total_cost) as avg_cost
FROM work_logs
WHERE deleted_at IS NULL
GROUP BY DATE_TRUNC('month', completed_at)
ORDER BY month DESC;
```

### Data Integrity Tests
```sql
-- Check foreign key constraints
SELECT 
  COUNT(*) as orphaned_work_logs
FROM work_logs wl
LEFT JOIN properties p ON wl.property_id = p.id
WHERE p.id IS NULL;  -- Should return 0

-- Verify audit trail
SELECT 
  entity_type,
  action,
  COUNT(*) as events
FROM audit_events
GROUP BY entity_type, action
ORDER BY entity_type, action;

-- Check user permissions
SELECT 
  u.email,
  o.name as organization,
  r.name as role,
  r.permissions
FROM users u
JOIN user_organization_roles uo ON u.id = uo.user_id
JOIN organizations o ON uo.organization_id = o.id
JOIN roles r ON uo.role_id = r.id
WHERE u.is_active = true AND uo.is_active = true;
```

## 🔍 Monitoring & Observability Testing

### Prometheus Metrics
```bash
# Check Prometheus targets
open http://localhost:9090/targets

# Query API metrics
curl "http://localhost:9090/api/v1/query?query=http_requests_total"

# Check specific business metrics
curl "http://localhost:9090/api/v1/query?query=work_logs_created_total"
```

### Grafana Dashboards
```bash
# Access Grafana
open http://localhost:3003
# Login: admin / admin123

# Test dashboards:
1. API Performance Dashboard
   - Response times should be < 100ms
   - Error rate should be 0%
   - Request rate should show activity

2. Business Metrics Dashboard  
   - Work log creation trends
   - Cost analysis by property
   - Document upload statistics

3. Infrastructure Dashboard
   - Database connection pool usage
   - Memory and CPU utilization
   - Service availability
```

### Log Analysis
```bash
# View structured logs
make logs

# Filter specific service logs
make logs-api
make logs-worker
make logs-db

# Search for specific events
docker-compose -f docker-compose.local.yml logs | grep "ERROR"
docker-compose -f docker-compose.local.yml logs | grep "login"
docker-compose -f docker-compose.local.yml logs | grep "work_log"
```

## 🚨 Error Scenario Testing

### Test Error Handling
```bash
# 1. Invalid authentication
curl -X GET http://localhost:3000/api/v1/properties
# Expected: 401 Unauthorized

# 2. Invalid token  
curl -H "Authorization: Bearer invalid_token" \
  http://localhost:3000/api/v1/properties
# Expected: 401 Unauthorized

# 3. Permission denied
# Login as tenant, try to create work log
curl -X POST -H "Authorization: Bearer $TENANT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Unauthorized Test"}' \
  http://localhost:3000/api/v1/work-logs  
# Expected: 403 Forbidden

# 4. Invalid data format
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"invalid": "data"}' \
  http://localhost:3000/api/v1/properties
# Expected: 400 Validation Error
```

### Database Connection Testing
```bash
# Stop database temporarily
docker-compose -f docker-compose.local.yml stop postgres

# Try API request (should return 503)
curl http://localhost:3000/health

# Restart database
docker-compose -f docker-compose.local.yml start postgres

# Verify recovery
curl http://localhost:3000/health
```

## ⚡ Performance Testing

### Load Testing
```bash
# Simple load test
make load-test

# Or manual with curl
for i in {1..100}; do
  curl -s -H "Authorization: Bearer $TOKEN" \
    http://localhost:3000/api/v1/properties > /dev/null &
done
wait

# Check response times in Grafana
open http://localhost:3003
```

### Benchmark Testing
```bash
# Run benchmark suite
make benchmark

# Check results in monitoring
# - API response times should be < 200ms p95
# - Database query times should be < 50ms
# - Memory usage should be stable
```

## 📱 Mobile/Responsive Testing

### Browser Testing
```bash
# Test in different viewports
open http://localhost:3001

# Test responsive breakpoints:
- Mobile: 320px - 767px
- Tablet: 768px - 1023px  
- Desktop: 1024px+

# Verify mobile-first features:
- Touch-friendly buttons
- Swipe gestures for image galleries
- Offline capability indicators
- Progressive loading
```

## 🔄 Integration Testing

### Full Workflow Testing
```bash
# Complete property maintenance workflow:

# 1. Admin creates new property
# 2. Property manager adds assets
# 3. Contractor receives work assignment
# 4. Contractor completes work and uploads photos
# 5. Property manager verifies completion
# 6. System generates notifications and audit trail
# 7. Auditor reviews compliance reports
```

## 🧹 Cleanup and Reset

### Reset Test Data
```bash
# Reset database with fresh seed data
make reset-db

# Full environment reset
make full-reset

# Clean up Docker resources
make clean
```

### Verify Clean State
```bash
# Check service status after reset
make health

# Verify data counts match seed data
make shell-db
```

```sql
-- Verify reset worked
SELECT 'organizations' as table_name, COUNT(*) as count FROM organizations
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL  
SELECT 'properties', COUNT(*) FROM properties
UNION ALL
SELECT 'work_logs', COUNT(*) FROM work_logs;
```

## 📋 Testing Checklist

### ✅ Basic Functionality
- [ ] All services start successfully
- [ ] Health checks pass for all services
- [ ] Database seeding completes
- [ ] Authentication works for all user types
- [ ] API endpoints respond correctly
- [ ] Frontend loads and functions

### ✅ Data Operations  
- [ ] CRUD operations work for all entities
- [ ] File uploads function correctly
- [ ] Search and filtering work
- [ ] Pagination handles large datasets
- [ ] Data validation prevents invalid input

### ✅ Security
- [ ] Unauthenticated requests are blocked
- [ ] Role-based permissions enforced
- [ ] Organization data isolation working
- [ ] File upload security restrictions active
- [ ] Rate limiting functions correctly

### ✅ Performance
- [ ] API responses under 200ms p95
- [ ] Database queries optimized
- [ ] File uploads handle large files
- [ ] Frontend loads quickly
- [ ] Memory usage stable under load

### ✅ Monitoring
- [ ] Metrics collection working
- [ ] Grafana dashboards populate
- [ ] Alerts can be triggered
- [ ] Logs are structured and searchable
- [ ] Health checks accurate

This comprehensive testing guide ensures your Property Upkeep Records system works correctly in the local development environment. Run through these scenarios regularly to catch issues early and maintain system reliability! 🚀