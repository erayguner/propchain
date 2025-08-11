# ⚡ Quick Start - Property Upkeep Records

Get up and running in **under 5 minutes** with a fully functional local development environment.

## 🚀 One-Command Setup

```bash
make setup-local
```

That's it! This single command will:
- ✅ Build all Docker containers
- ✅ Start 12 services (API, DB, Redis, Monitoring, etc.)
- ✅ Configure AWS LocalStack resources
- ✅ Seed database with realistic test data
- ✅ Set up Prometheus monitoring & Grafana dashboards

## 🎯 Quick Access Links

Once setup is complete, access these URLs:

| Service | URL | Purpose |
|---------|-----|---------|
| 🏠 **Frontend** | [localhost:3001](http://localhost:3001) | Main application |
| 🔌 **API** | [localhost:3000](http://localhost:3000) | REST API |
| 📚 **API Docs** | [localhost:3000/api/docs](http://localhost:3000/api/docs) | Interactive API documentation |
| 📊 **Grafana** | [localhost:3003](http://localhost:3003) | Monitoring dashboards |
| 🗄️ **Database** | [localhost:8080](http://localhost:8080) | Database admin interface |
| 📧 **Email** | [localhost:1080](http://localhost:1080) | Email testing interface |

## 👤 Test Login

Use these credentials to test different user roles:

```bash
# Property Manager (Full access)
Email: manager@acme-property.com
Password: password123

# Contractor (Work completion)  
Email: contractor1@example.com
Password: password123

# Tenant (View-only)
Email: tenant@example.com  
Password: password123
```

## ✅ Verify Everything Works

```bash
# Check all services are healthy
make health

# View real-time logs
make logs

# Test API directly
curl http://localhost:3000/health
```

## 🎮 Try These Features

### 1. **Property Management**
- Login as manager → View properties → Browse work history
- See cost breakdowns, maintenance schedules, asset tracking

### 2. **Work Log Creation** 
- Login as contractor → Create new work log → Upload photos
- Test the complete maintenance workflow

### 3. **Monitoring Dashboard**
- Visit Grafana ([localhost:3003](http://localhost:3003)) → admin/admin123
- View real-time API metrics, database performance, business KPIs

### 4. **API Testing**
- Visit API docs ([localhost:3000/api/docs](http://localhost:3000/api/docs))
- Try the interactive endpoints with real data

## 🛠️ Common Commands

```bash
# Start environment
make up

# Stop everything  
make down

# Reset with fresh data
make reset-db

# Run tests
make test

# View specific service logs
make logs-api
make logs-db
```

## 🆘 Quick Fixes

**Services won't start?**
```bash
make clean && make setup-local
```

**Database issues?**
```bash
make reset-db
```

**Port conflicts?**
```bash
# Find what's using port 3000
lsof -i :3000
# Kill the process
sudo kill -9 <PID>
```

## 📱 What You Get

This environment includes:

- ✅ **Full-stack application** with React frontend
- ✅ **RESTful API** with authentication & authorization  
- ✅ **PostgreSQL database** with realistic seed data
- ✅ **Real-time monitoring** with Prometheus & Grafana
- ✅ **File upload** with S3-compatible MinIO storage
- ✅ **Email testing** with MailCatcher
- ✅ **API documentation** with Swagger/OpenAPI
- ✅ **Multi-tenant architecture** with RBAC security
- ✅ **Background job processing** with SQS queues

## 🎯 Next Steps

1. **Explore the Frontend** - Login and browse the application
2. **Test the API** - Use the interactive API documentation  
3. **Check Monitoring** - View dashboards and metrics
4. **Review Code** - Examine the well-structured codebase
5. **Run Tests** - Execute the comprehensive test suite

## 📚 More Information

- [Full README](./README.md) - Comprehensive documentation
- [Testing Guide](./TESTING_GUIDE.md) - Complete testing scenarios  
- [Technical Spec](./TECHNICAL_SPECIFICATION.md) - Detailed system design

---

**Ready to build property management software?** Start with `make setup-local` and you'll have a production-ready development environment in minutes! 🚀

**Having issues?** Check the logs with `make logs` or reset everything with `make full-reset`.