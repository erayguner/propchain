# 🔧 Troubleshooting Guide - Property Upkeep Records

Quick fixes for common issues in the local development environment.

## 🚨 Initial Setup Issues

### Docker Build Failures

**Issue**: Services fail to build with missing Dockerfile errors
```bash
target frontend: failed to solve: failed to read dockerfile: open Dockerfile.dev: no such file or directory
```

**Fix**:
```bash
# Remove the version line from docker-compose.local.yml (already fixed)
# Rebuild all containers
make clean
make build
make up
```

### Port Conflicts

**Issue**: Ports already in use
```bash
Error: bind: address already in use
```

**Fix**:
```bash
# Check what's using the ports
lsof -i :3000  # API
lsof -i :5432  # PostgreSQL
lsof -i :6379  # Redis
lsof -i :3001  # Frontend

# Kill conflicting processes
sudo kill -9 <PID>

# Or change ports in docker-compose.local.yml
```

### Permission Issues

**Issue**: Permission denied errors on macOS/Linux
```bash
Permission denied while trying to connect to the Docker daemon
```

**Fix**:
```bash
# Add user to docker group (Linux)
sudo usermod -aG docker $USER
newgrp docker

# On macOS, ensure Docker Desktop is running
# Restart Docker Desktop if needed
```

## 🗄 Database Issues

### Database Connection Failures

**Issue**: API can't connect to database
```bash
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**Fix**:
```bash
# Check if PostgreSQL is running
docker-compose -f docker-compose.local.yml ps postgres

# Restart database
docker-compose -f docker-compose.local.yml restart postgres

# Check logs
make logs-db

# Reset database completely
make reset-db
```

### Database Seeding Errors

**Issue**: Seed data fails to load
```bash
ERROR: relation "organizations" does not exist
```

**Fix**:
```bash
# Reset database with fresh schema and data
make reset-db

# Manually run seeding
docker-compose -f docker-compose.local.yml exec postgres psql -U propchain -d propchain_dev -f /seed-data/01_schema.sql
docker-compose -f docker-compose.local.yml exec postgres psql -U propchain -d propchain_dev -f /seed-data/02_test_data.sql
```

### Migration Issues

**Issue**: Schema out of sync
```bash
ERROR: column "new_column" does not exist
```

**Fix**:
```bash
# Connect to database
make shell-db

# Check current schema
\dt

# Drop and recreate schema (CAUTION: loses data)
DROP SCHEMA propchain CASCADE;
CREATE SCHEMA propchain;
\q

# Re-run seeding
make reset-db
```

## 🔌 API Issues

### API Server Won't Start

**Issue**: Node.js API crashes on startup
```bash
Error: Cannot find module 'express'
```

**Fix**:
```bash
# Rebuild API container
docker-compose -f docker-compose.local.yml build api_server

# Check if dependencies installed
docker-compose -f docker-compose.local.yml exec api_server npm list

# Reinstall dependencies
docker-compose -f docker-compose.local.yml exec api_server npm install
```

### Authentication Issues

**Issue**: Login returns 401 Unauthorized
```bash
{"error": "Unauthorized", "message": "Invalid email or password"}
```

**Fix**:
```bash
# Check auth service is running
curl http://localhost:3002/health

# Verify test users exist
make shell-db
SELECT email, first_name, last_name FROM users;

# Reset auth mock service
docker-compose -f docker-compose.local.yml restart auth_mock
```

### JWT Token Issues

**Issue**: Token validation fails
```bash
{"error": "Unauthorized", "message": "Invalid or expired token"}
```

**Fix**:
```bash
# Check JWT secret consistency
# Ensure JWT_SECRET is same in API and auth-mock
grep JWT_SECRET .env.local

# Clear browser storage and re-login
# In browser console:
localStorage.clear();
location.reload();
```

## 🌐 Frontend Issues

### React Development Server Issues

**Issue**: Frontend won't start or hot reload not working
```bash
Error: ENOSPC: System limit for number of file watchers reached
```

**Fix**:
```bash
# Increase file watcher limit (Linux)
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

# On macOS/Windows, restart Docker Desktop
# Clear node_modules and reinstall
docker-compose -f docker-compose.local.yml exec frontend rm -rf node_modules
docker-compose -f docker-compose.local.yml exec frontend npm install
```

### Build Errors

**Issue**: Vite build failures
```bash
✘ [ERROR] Could not resolve "react-router-dom"
```

**Fix**:
```bash
# Check dependencies
docker-compose -f docker-compose.local.yml exec frontend npm list react-router-dom

# Install missing dependencies
docker-compose -f docker-compose.local.yml exec frontend npm install

# Clear cache and rebuild
docker-compose -f docker-compose.local.yml exec frontend npm run build
```

### API Connection Issues

**Issue**: Frontend can't reach API
```bash
Network Error: Failed to fetch
```

**Fix**:
```bash
# Check API is accessible
curl http://localhost:3000/health

# Verify CORS settings
# Check .env.local has correct CORS_ORIGIN

# Test with direct API call
curl -H "Content-Type: application/json" \
  -d '{"email":"admin@acme-property.com","password":"password123"}' \
  http://localhost:3000/api/v1/auth/login
```

## 📊 Monitoring Issues

### Grafana Dashboard Empty

**Issue**: No data showing in Grafana dashboards
```bash
No data points found
```

**Fix**:
```bash
# Check Prometheus is scraping targets
open http://localhost:9090/targets

# Verify API is exposing metrics
curl http://localhost:3000/metrics

# Check Grafana datasource configuration
# Login to Grafana → Configuration → Data Sources
# Ensure Prometheus URL is correct: http://propchain_prometheus:9090
```

### Prometheus Scraping Issues

**Issue**: Targets show as DOWN in Prometheus
```bash
Get "http://propchain_api:3000/metrics": dial tcp: lookup propchain_api on 127.0.0.11:53: no such host
```

**Fix**:
```bash
# Check all containers are on same network
docker network ls
docker network inspect propchain_network

# Restart Prometheus
docker-compose -f docker-compose.local.yml restart prometheus

# Check service names match docker-compose
docker-compose -f docker-compose.local.yml ps
```

## 🚀 Performance Issues

### Slow API Responses

**Issue**: API responses take > 5 seconds
```bash
Request timeout after 10000ms
```

**Fix**:
```bash
# Check database query performance
make shell-db
EXPLAIN ANALYZE SELECT * FROM work_logs WHERE organization_id = '...';

# Monitor resource usage
docker stats

# Check for connection pool exhaustion
make logs-api | grep "connection"

# Restart services if needed
make restart
```

### High Memory Usage

**Issue**: Containers using excessive memory
```bash
Docker Desktop using 8GB+ RAM
```

**Fix**:
```bash
# Check memory usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Reduce container resource limits in docker-compose.local.yml
# Restart with new limits
make down
make up
```

### Disk Space Issues

**Issue**: Docker taking too much disk space
```bash
Error response from daemon: no space left on device
```

**Fix**:
```bash
# Clean up Docker system
docker system prune -f
docker image prune -f
docker volume prune -f

# Check disk usage
docker system df

# Remove old containers and images
make clean
```

## 🔄 Network Issues

### Container Communication Issues

**Issue**: Services can't reach each other
```bash
connect: connection refused
```

**Fix**:
```bash
# Check all services are on same network
docker-compose -f docker-compose.local.yml ps

# Verify network configuration
docker network inspect propchain_network

# Restart with network recreation
make down
docker network rm propchain_network
make up
```

### DNS Resolution Issues

**Issue**: Service names not resolving
```bash
getaddrinfo ENOTFOUND propchain_postgres
```

**Fix**:
```bash
# Use IP addresses temporarily
docker inspect propchain_postgres | grep IPAddress

# Or restart Docker Desktop
# On Linux, restart Docker daemon:
sudo systemctl restart docker
```

## 📱 Mobile/Browser Issues

### HTTPS/SSL Issues in Development

**Issue**: Mixed content warnings or HTTPS required
```bash
This request has been blocked; the content must be served over HTTPS
```

**Fix**:
```bash
# For development, use HTTP
# Update VITE_API_URL in frontend/.env
VITE_API_URL=http://localhost:3000/api/v1

# Or add SSL certificates to nginx/certs/
# Self-signed certs for development:
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/localhost.key \
  -out nginx/certs/localhost.crt \
  -subj "/CN=localhost"
```

### Browser Caching Issues

**Issue**: Old code still loading after changes
```bash
Changes not reflecting in browser
```

**Fix**:
```bash
# Hard refresh in browser
Ctrl+F5 (Windows/Linux) or Cmd+Shift+R (Mac)

# Clear browser cache and storage
# In browser console:
localStorage.clear();
sessionStorage.clear();
caches.keys().then(names => names.forEach(name => caches.delete(name)));
location.reload();
```

## 🔧 Quick Diagnostic Commands

### Check Everything is Running
```bash
make health
make status
```

### View All Logs
```bash
make logs
```

### Check Specific Service
```bash
make logs-api
make logs-db
make logs-worker
```

### Test API Endpoints
```bash
# Health check
curl http://localhost:3000/health

# Auth test
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@acme-property.com","password":"password123"}'
```

### Database Quick Check
```bash
make shell-db
# Then in psql:
SELECT COUNT(*) FROM organizations;
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM properties;
\q
```

### Resource Usage
```bash
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
```

## 🆘 Nuclear Options (Last Resort)

### Complete Reset
```bash
# This will destroy all data and start fresh
make full-reset
```

### Docker System Reset
```bash
# WARNING: This removes ALL Docker data
docker system prune -af --volumes
docker volume rm $(docker volume ls -q)
make setup-local
```

### Individual Service Reset
```bash
# Reset specific service
docker-compose -f docker-compose.local.yml stop postgres
docker-compose -f docker-compose.local.yml rm -f postgres
docker volume rm propchain_postgres_data
docker-compose -f docker-compose.local.yml up -d postgres
make reset-db
```

## 📞 Getting Help

If you're still having issues:

1. **Check the logs first**: `make logs`
2. **Search the codebase**: Look for similar configurations or error handling
3. **Verify your environment**: Compare with `.env.example`
4. **Try the nuclear options**: Sometimes a clean slate helps
5. **Check Docker resources**: Ensure adequate CPU/memory allocated

Remember: Most issues are environment-specific. The nuclear reset option (`make full-reset`) fixes 90% of issues but takes a few minutes to rebuild everything.

---

**Pro tip**: Keep a log of what you were doing when an issue occurred. This helps identify patterns and prevent repeat issues! 🚀