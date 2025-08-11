# Property Upkeep Records System - Operational Runbooks

## Table of Contents

1. [Overview](#overview)
2. [Emergency Response](#emergency-response)
3. [Deployment Procedures](#deployment-procedures)
4. [Backup and Recovery](#backup-and-recovery)
5. [Monitoring and Alerting](#monitoring-and-alerting)
6. [Troubleshooting Guide](#troubleshooting-guide)
7. [Maintenance Procedures](#maintenance-procedures)
8. [Security Incident Response](#security-incident-response)
9. [Capacity Management](#capacity-management)
10. [Disaster Recovery](#disaster-recovery)

## Overview

This document provides operational procedures for the Property Upkeep Records system. These runbooks are designed to help operations teams respond to incidents, perform maintenance, and ensure system reliability.

### Key Contacts

- **Primary On-Call**: DevOps Team (+44-xxx-xxx-xxxx)
- **Secondary On-Call**: Development Team (+44-xxx-xxx-xxxx)
- **Business Contact**: Product Manager (+44-xxx-xxx-xxxx)
- **Emergency Escalation**: CTO (+44-xxx-xxx-xxxx)

### System Architecture Overview

- **Frontend**: React application served by NGINX
- **Backend API**: Node.js/TypeScript application
- **Database**: PostgreSQL with Row-Level Security
- **Cache**: Redis ElastiCache
- **Queues**: AWS SQS for async processing
- **Storage**: S3 for documents and backups
- **Monitoring**: Prometheus + Grafana + AlertManager

---

## Emergency Response

### Incident Classification

| Severity | Description | Response Time | Examples |
|----------|-------------|---------------|----------|
| **P0 - Critical** | System completely down | 15 minutes | Complete service outage, data loss |
| **P1 - High** | Major functionality impacted | 1 hour | Authentication down, file uploads failing |
| **P2 - Medium** | Some functionality impacted | 4 hours | Slow response times, non-critical features down |
| **P3 - Low** | Minor issues | Next business day | UI bugs, minor performance issues |

### Emergency Response Procedure

#### 1. Immediate Assessment (0-5 minutes)
```bash
# Check overall system health
curl -f https://api.propchain.com/health

# Check monitoring dashboards
echo "Check Grafana: https://monitoring.propchain.com/d/overview"
echo "Check AWS Console: https://console.aws.amazon.com/cloudwatch/"
```

#### 2. Initial Response (5-15 minutes)
```bash
# Check service status
docker-compose ps  # For local development
kubectl get pods   # For Kubernetes

# Check recent logs
docker logs propchain-api --tail=100
kubectl logs -l app=propchain-api --tail=100

# Check database connectivity
psql -h $DATABASE_HOST -U $DATABASE_USER -d $DATABASE_NAME -c "SELECT 1;"

# Check Redis connectivity
redis-cli -h $REDIS_HOST -p $REDIS_PORT ping
```

#### 3. Communication (Within 15 minutes)
- Post incident status in #incidents Slack channel
- Update status page if customer-facing
- Notify stakeholders based on severity level

#### 4. Investigation Template
```markdown
## Incident Response Log

**Incident ID**: INC-YYYY-MM-DD-NNN
**Start Time**: YYYY-MM-DD HH:MM UTC
**Severity**: P0/P1/P2/P3
**Status**: Investigating/Mitigated/Resolved

### Timeline
- HH:MM - Issue detected
- HH:MM - Investigation started
- HH:MM - Root cause identified
- HH:MM - Fix implemented
- HH:MM - Service restored

### Impact
- Services affected:
- Users affected:
- Duration:

### Root Cause
[Description of what caused the issue]

### Resolution
[Description of what was done to fix it]

### Follow-up Actions
- [ ] Post-mortem scheduled
- [ ] Monitoring improvements
- [ ] Documentation updates
```

---

## Deployment Procedures

### Pre-Deployment Checklist

- [ ] All tests passing in CI/CD pipeline
- [ ] Security scan completed
- [ ] Database migrations tested
- [ ] Rollback plan confirmed
- [ ] Monitoring alerts configured
- [ ] Stakeholders notified

### Standard Deployment

#### 1. Pre-deployment Validation
```bash
# Verify current system status
curl -f https://api.propchain.com/health

# Check database connection
npm run db:check

# Verify queue health
npm run queue:health

# Check recent error rates
curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status_code=~\"5..\"}[5m])"
```

#### 2. Database Migration (if required)
```bash
# Backup current database
pg_dump -h $DATABASE_HOST -U $DATABASE_USER $DATABASE_NAME > backup_$(date +%Y%m%d_%H%M).sql

# Run migrations in transaction
npm run migrate:up

# Verify migration success
npm run migrate:status
```

#### 3. Application Deployment
```bash
# For Docker Compose
docker-compose pull
docker-compose up -d --remove-orphans

# For Kubernetes
kubectl set image deployment/propchain-api api=propchain/api:v1.2.3
kubectl rollout status deployment/propchain-api --timeout=300s
```

#### 4. Post-Deployment Validation
```bash
# Health check
curl -f https://api.propchain.com/health

# Smoke tests
npm run test:smoke

# Check error rates for 10 minutes
watch -n 30 'curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status_code=~\"5..\"}[5m])"'
```

### Rollback Procedure

#### Immediate Rollback
```bash
# For Docker Compose
docker-compose down
docker-compose up -d --remove-orphans

# For Kubernetes
kubectl rollout undo deployment/propchain-api
kubectl rollout status deployment/propchain-api --timeout=300s
```

#### Database Rollback
```bash
# If migration rollback needed
npm run migrate:down

# If data restore needed (EXTREME CAUTION)
pg_restore -h $DATABASE_HOST -U $DATABASE_USER -d $DATABASE_NAME backup_file.sql
```

---

## Backup and Recovery

### Database Backup Procedures

#### Automated Backups
- **RDS Automated Backups**: 30 days retention (production), 7 days (staging)
- **Point-in-time Recovery**: Available for RDS instances
- **Cross-region Backup**: Enabled for production environments

#### Manual Backup
```bash
# Create full database backup
pg_dump -h $DATABASE_HOST -U $DATABASE_USER -Fc $DATABASE_NAME > propchain_backup_$(date +%Y%m%d_%H%M).dump

# Upload to S3
aws s3 cp propchain_backup_$(date +%Y%m%d_%H%M).dump s3://propchain-backups/manual/

# Verify backup integrity
pg_restore --list propchain_backup_$(date +%Y%m%d_%H%M).dump
```

#### Backup Validation
```bash
# Monthly backup validation script
#!/bin/bash
BACKUP_FILE="propchain_backup_$(date +%Y%m%d).dump"
TEST_DB="propchain_test_restore"

# Download latest backup
aws s3 cp s3://propchain-backups/automated/latest.dump $BACKUP_FILE

# Create test database
createdb -h $DATABASE_HOST -U $DATABASE_USER $TEST_DB

# Restore backup
pg_restore -h $DATABASE_HOST -U $DATABASE_USER -d $TEST_DB $BACKUP_FILE

# Validate data integrity
psql -h $DATABASE_HOST -U $DATABASE_USER -d $TEST_DB -c "
  SELECT 
    COUNT(*) as user_count,
    (SELECT COUNT(*) FROM properties) as property_count,
    (SELECT COUNT(*) FROM work_logs) as work_log_count
  FROM users;
"

# Cleanup
dropdb -h $DATABASE_HOST -U $DATABASE_USER $TEST_DB
rm $BACKUP_FILE
```

### File Storage Backup

#### Document Backup
```bash
# S3 cross-region replication is configured automatically
# Manual sync to backup region
aws s3 sync s3://propchain-documents-prod s3://propchain-documents-backup-eu-west-1 --region eu-west-1
```

#### Backup Monitoring
```bash
# Check backup age
aws s3 ls s3://propchain-backups/automated/ --recursive | tail -5

# Verify backup sizes
aws s3 ls s3://propchain-backups/automated/ --recursive --human-readable --summarize
```

### Recovery Procedures

#### Database Recovery

**Scenario 1: Point-in-time Recovery**
```bash
# Use AWS RDS point-in-time recovery
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier propchain-prod-db \
  --target-db-instance-identifier propchain-restored-$(date +%Y%m%d-%H%M) \
  --restore-time 2024-01-15T10:30:00Z \
  --subnet-group-name propchain-db-subnet-group \
  --vpc-security-group-ids sg-xxxxxxxxx
```

**Scenario 2: Full Database Restore**
```bash
# Create new database instance
aws rds create-db-instance \
  --db-instance-identifier propchain-recovery-$(date +%Y%m%d) \
  --db-instance-class db.t3.large \
  --engine postgres \
  --allocated-storage 100

# Restore from backup
pg_restore -h $RECOVERY_DB_HOST -U $DB_USER -d $DB_NAME backup_file.dump

# Update application configuration
kubectl patch deployment propchain-api -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","env":[{"name":"DATABASE_URL","value":"new_database_url"}]}]}}}}'
```

#### Application Recovery

**Scenario 1: Container Recovery**
```bash
# Restart failed containers
docker-compose restart propchain-api
docker-compose restart propchain-worker

# Or for Kubernetes
kubectl delete pods -l app=propchain-api
kubectl delete pods -l app=propchain-worker
```

**Scenario 2: Complete Service Recovery**
```bash
# Redeploy from last known good version
kubectl set image deployment/propchain-api api=propchain/api:v1.2.2
kubectl rollout status deployment/propchain-api
```

---

## Monitoring and Alerting

### Key Metrics to Monitor

#### Application Metrics
- **Response Time**: P95 < 300ms, P99 < 1s
- **Error Rate**: < 0.1% for 5xx errors
- **Throughput**: Requests per second
- **Active Users**: Concurrent user sessions

#### Infrastructure Metrics
- **CPU Usage**: < 70% average, < 90% peak
- **Memory Usage**: < 80% average, < 95% peak
- **Disk Space**: > 20% free space remaining
- **Network I/O**: Monitor for unusual patterns

#### Business Metrics
- **Work Logs Created**: Track creation rate
- **Document Uploads**: Success/failure rates
- **User Logins**: Authentication success rates
- **Queue Depth**: Messages pending processing

### Alert Response Procedures

#### High Error Rate Alert
```bash
# Check recent errors
kubectl logs -l app=propchain-api --since=10m | grep ERROR

# Check database connectivity
psql -h $DATABASE_HOST -U $DATABASE_USER -c "SELECT 1;"

# Check external service dependencies
curl -f https://auth-provider.com/health
curl -f https://notification-service.com/health

# If errors persist, consider:
# 1. Scale up application instances
# 2. Enable maintenance mode
# 3. Rollback recent deployment
```

#### High Response Time Alert
```bash
# Check current load
kubectl top pods -l app=propchain-api

# Check database performance
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT query, mean_time, calls 
  FROM pg_stat_statements 
  ORDER BY mean_time DESC 
  LIMIT 10;
"

# Check for slow queries
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT query, state, query_start, now() - query_start AS duration
  FROM pg_stat_activity 
  WHERE state = 'active' 
  AND now() - query_start > interval '30 seconds';
"

# Scale up if needed
kubectl scale deployment propchain-api --replicas=6
```

#### Queue Backlog Alert
```bash
# Check queue status
aws sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names All

# Check worker status
kubectl logs -l app=propchain-worker --since=10m

# Scale up workers if needed
kubectl scale deployment propchain-worker --replicas=5

# Check for dead letter queue messages
aws sqs get-queue-attributes --queue-url $DLQ_URL --attribute-names ApproximateNumberOfMessages
```

#### Database Connection Alert
```bash
# Check active connections
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT count(*) as active_connections,
         max_conn,
         max_conn - count(*) as available_connections
  FROM pg_stat_activity, (SELECT setting::int AS max_conn FROM pg_settings WHERE name='max_connections') max_conn;
"

# Check connection pool status
kubectl logs -l app=propchain-api | grep "connection pool"

# If connections exhausted:
# 1. Restart application pods
# 2. Check for connection leaks
# 3. Consider increasing max_connections
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Application Won't Start

**Symptoms**: Health check fails, container keeps restarting
```bash
# Check container logs
docker logs propchain-api --tail=100

# Common causes:
# - Database connection failure
# - Missing environment variables
# - Port already in use
# - Resource constraints

# Debugging steps:
# 1. Verify environment variables
docker exec propchain-api env | grep DATABASE_URL

# 2. Test database connection
docker exec propchain-api npm run db:test

# 3. Check resource usage
docker stats propchain-api
```

#### 2. Slow Database Performance

**Symptoms**: High response times, timeouts
```bash
# Check current queries
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT pid, now() - pg_stat_activity.query_start AS duration, query
  FROM pg_stat_activity
  WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
"

# Check table statistics
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT schemaname,tablename,attname,n_distinct,correlation
  FROM pg_stats
  WHERE tablename IN ('work_logs', 'properties', 'documents')
  ORDER BY tablename, attname;
"

# Update table statistics if needed
psql -h $DATABASE_HOST -U $DATABASE_USER -c "ANALYZE;"

# Check for missing indexes
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT schemaname, tablename, attname, n_distinct, correlation
  FROM pg_stats
  WHERE schemaname = 'public'
  ORDER BY n_distinct DESC;
"
```

#### 3. High Memory Usage

**Symptoms**: Out of memory errors, slow performance
```bash
# Check memory usage by process
docker exec propchain-api ps aux --sort=-%mem | head

# Check Node.js heap usage
docker exec propchain-api node -e "console.log(process.memoryUsage())"

# Monitor memory over time
docker exec propchain-api node -e "
  setInterval(() => {
    const mem = process.memoryUsage();
    console.log(\`\${new Date().toISOString()} - RSS: \${(mem.rss/1024/1024).toFixed(2)}MB, Heap: \${(mem.heapUsed/1024/1024).toFixed(2)}MB\`);
  }, 5000);
"

# If memory leak suspected:
# 1. Restart the application
# 2. Monitor memory growth patterns
# 3. Check for unclosed database connections
# 4. Review recent code changes
```

#### 4. Queue Processing Issues

**Symptoms**: Messages not processing, growing queue depth
```bash
# Check queue attributes
aws sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names All | jq '.'

# Check worker logs
kubectl logs -l app=propchain-worker --since=30m

# Check dead letter queue
aws sqs receive-message --queue-url $DLQ_URL --max-number-of-messages 5

# Manual message processing for debugging
aws sqs receive-message --queue-url $QUEUE_URL --wait-time-seconds 20

# Purge queue if needed (CAUTION!)
aws sqs purge-queue --queue-url $QUEUE_URL
```

#### 5. File Upload Problems

**Symptoms**: Upload failures, incomplete files
```bash
# Check S3 bucket permissions
aws s3api get-bucket-policy --bucket propchain-documents-prod

# Check recent uploads
aws s3 ls s3://propchain-documents-prod/ --recursive --human-readable | tail -10

# Test upload manually
aws s3 cp test-file.txt s3://propchain-documents-prod/test/

# Check application logs for upload errors
kubectl logs -l app=propchain-api | grep -i upload | tail -20

# Verify disk space on application servers
kubectl exec -it deployment/propchain-api -- df -h
```

### Debug Mode Activation

#### Application Debug Mode
```bash
# Enable debug logging temporarily
kubectl set env deployment/propchain-api LOG_LEVEL=debug

# Revert after debugging
kubectl set env deployment/propchain-api LOG_LEVEL=info
```

#### Database Query Logging
```bash
# Enable query logging (temporary)
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  ALTER SYSTEM SET log_statement = 'all';
  SELECT pg_reload_conf();
"

# Disable after debugging
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  ALTER SYSTEM SET log_statement = 'none';
  SELECT pg_reload_conf();
"
```

---

## Maintenance Procedures

### Scheduled Maintenance Windows

- **Weekly**: Sunday 02:00-04:00 UTC (Low traffic period)
- **Monthly**: First Sunday of month 02:00-06:00 UTC
- **Emergency**: As needed with 2-hour notice

### Pre-Maintenance Checklist

- [ ] Maintenance window scheduled and communicated
- [ ] All recent backups verified
- [ ] Rollback plan documented and tested
- [ ] Monitoring alerts adjusted for maintenance
- [ ] Status page updated

### Database Maintenance

#### Weekly Tasks
```bash
# Update table statistics
psql -h $DATABASE_HOST -U $DATABASE_USER -c "ANALYZE;"

# Check for bloated tables
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT schemaname, tablename, 
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
         pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size
  FROM pg_tables 
  WHERE schemaname = 'public'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"

# Vacuum full on large tables (if needed)
psql -h $DATABASE_HOST -U $DATABASE_USER -c "VACUUM FULL work_logs;"
```

#### Monthly Tasks
```bash
# Update PostgreSQL statistics
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  ANALYZE;
  VACUUM ANALYZE;
"

# Check index usage
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch
  FROM pg_stat_user_indexes
  WHERE idx_tup_read = 0 OR idx_tup_fetch = 0
  ORDER BY schemaname, tablename;
"

# Rebuild indexes if needed
psql -h $DATABASE_HOST -U $DATABASE_USER -c "REINDEX DATABASE $DATABASE_NAME;"
```

### Application Maintenance

#### Log Rotation
```bash
# Archive old logs
docker exec propchain-api sh -c "find /var/log -name '*.log' -mtime +7 -exec gzip {} \;"

# Clean up old log files
docker exec propchain-api sh -c "find /var/log -name '*.log.gz' -mtime +30 -delete"
```

#### Cache Maintenance
```bash
# Clear Redis cache (if needed)
redis-cli -h $REDIS_HOST -p $REDIS_PORT FLUSHALL

# Check Redis memory usage
redis-cli -h $REDIS_HOST -p $REDIS_PORT INFO memory
```

#### Certificate Renewal
```bash
# Check certificate expiration
echo | openssl s_client -servername api.propchain.com -connect api.propchain.com:443 2>/dev/null | openssl x509 -noout -dates

# Renew Let's Encrypt certificates (if using)
certbot renew --dry-run
certbot renew

# Update certificates in load balancer
aws acm list-certificates --certificate-statuses ISSUED
```

### System Updates

#### Operating System Updates
```bash
# For container-based deployments
# Build new images with updated base images
docker build -t propchain/api:v1.2.3-updated .
docker push propchain/api:v1.2.3-updated

# Deploy updated images
kubectl set image deployment/propchain-api api=propchain/api:v1.2.3-updated
```

#### Dependency Updates
```bash
# Check for outdated packages
npm audit
npm outdated

# Update non-breaking changes
npm update

# Test thoroughly before deploying breaking changes
npm test
npm run test:integration
npm run test:e2e
```

---

## Security Incident Response

### Incident Classification

| Level | Description | Response Time | Actions |
|-------|-------------|---------------|---------|
| **Critical** | Active breach, data exposure | Immediate | Isolate systems, notify authorities |
| **High** | Suspected breach, vulnerability | 1 hour | Investigate, implement controls |
| **Medium** | Security alerts, unusual activity | 4 hours | Monitor, analyze patterns |
| **Low** | Policy violations, minor issues | 24 hours | Document, schedule remediation |

### Immediate Response Procedures

#### 1. Detect and Verify (0-15 minutes)
```bash
# Check for suspicious activity
grep -i "failed login" /var/log/auth.log | tail -20

# Review recent API access
kubectl logs -l app=propchain-api | grep -E "(401|403|429)" | tail -50

# Check database access patterns
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT query, state, query_start, client_addr
  FROM pg_stat_activity 
  WHERE state = 'active';
"
```

#### 2. Contain (15-30 minutes)
```bash
# Block suspicious IPs at load balancer
aws elbv2 modify-rule --rule-arn $RULE_ARN --conditions Field=source-ip,Values="192.168.1.100/32"

# Temporarily block access if needed
kubectl scale deployment propchain-api --replicas=0

# Revoke suspicious API tokens
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  UPDATE users SET is_active = false 
  WHERE last_login_at > '2024-01-01' AND email LIKE '%suspicious%';
"
```

#### 3. Investigate (30 minutes - 2 hours)
```bash
# Export relevant logs
kubectl logs -l app=propchain-api --since=24h > incident_logs_$(date +%Y%m%d).log

# Check access logs
aws s3 cp s3://propchain-alb-logs/$(date +%Y/%m/%d)/ ./investigation/ --recursive

# Database audit trail
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  SELECT * FROM audit_events 
  WHERE created_at > NOW() - INTERVAL '24 hours'
  AND action IN ('CREATE', 'UPDATE', 'DELETE')
  ORDER BY created_at DESC
  LIMIT 100;
"
```

#### 4. Recovery and Communication
```bash
# Reset compromised credentials
kubectl create secret generic api-secrets \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  --from-literal=db-password=$(openssl rand -base64 32)

# Force password reset for affected users
psql -h $DATABASE_HOST -U $DATABASE_USER -c "
  UPDATE users SET password_hash = NULL, email_verified = false
  WHERE id IN ('list-of-affected-user-ids');
"

# Restore service
kubectl scale deployment propchain-api --replicas=3
```

### Security Hardening Checklist

#### Application Security
- [ ] All dependencies updated and scanned
- [ ] API authentication and authorization working
- [ ] Input validation implemented
- [ ] SQL injection protection verified
- [ ] XSS protection headers configured
- [ ] Rate limiting active
- [ ] Audit logging enabled

#### Infrastructure Security  
- [ ] Security groups properly configured
- [ ] Database encryption at rest enabled
- [ ] TLS encryption in transit verified
- [ ] VPN access only for administrators
- [ ] Multi-factor authentication required
- [ ] Regular security scanning scheduled
- [ ] Intrusion detection monitoring active

---

## Capacity Management

### Performance Baselines

#### Normal Operating Parameters
- **API Response Time**: P95 < 200ms, P99 < 500ms
- **Database Connections**: < 50 active connections
- **Memory Usage**: < 70% of allocated memory
- **CPU Usage**: < 60% average utilization
- **Queue Depth**: < 10 messages pending

#### Load Testing
```bash
# API load testing with wrk
wrk -t12 -c400 -d30s --script=load-test.lua https://api.propchain.com/api/v1/properties

# Database connection testing
pgbench -h $DATABASE_HOST -U $DATABASE_USER -d $DATABASE_NAME -c 20 -j 4 -T 300

# Queue processing testing
node scripts/queue-load-test.js --messages=1000 --concurrent=10
```

#### Scaling Triggers

**Scale Up Conditions**:
- CPU usage > 70% for 5 minutes
- Memory usage > 80% for 10 minutes  
- Response time P95 > 300ms for 5 minutes
- Queue depth > 50 messages for 10 minutes

**Scale Down Conditions**:
- CPU usage < 30% for 30 minutes
- Memory usage < 50% for 30 minutes
- Response time P95 < 150ms for 30 minutes
- Queue depth < 5 messages for 30 minutes

#### Scaling Procedures

**Application Scaling**:
```bash
# Manual scaling
kubectl scale deployment propchain-api --replicas=6

# Enable auto-scaling
kubectl autoscale deployment propchain-api --cpu-percent=70 --min=2 --max=10

# Check scaling status
kubectl get hpa propchain-api
```

**Database Scaling**:
```bash
# Scale up RDS instance
aws rds modify-db-instance \
  --db-instance-identifier propchain-prod-db \
  --db-instance-class db.r6g.xlarge \
  --apply-immediately

# Enable read replicas for scaling reads
aws rds create-db-instance-read-replica \
  --db-instance-identifier propchain-prod-db-replica \
  --source-db-instance-identifier propchain-prod-db
```

### Capacity Planning

#### Growth Projections
- **Users**: 20% monthly growth expected
- **Data Storage**: 5GB per month increase
- **API Requests**: 30% increase quarter-over-quarter
- **Document Storage**: 2GB per month increase

#### Resource Planning Matrix

| Metric | Current | 3 Months | 6 Months | 1 Year | Action Required |
|--------|---------|----------|----------|---------|-----------------|
| Daily API Requests | 100K | 150K | 200K | 350K | Scale API instances |
| Database Size | 10GB | 25GB | 40GB | 80GB | Plan storage increase |
| Concurrent Users | 50 | 100 | 150 | 300 | Load balancer capacity |
| Document Storage | 50GB | 75GB | 100GB | 200GB | S3 cost optimization |

---

## Disaster Recovery

### Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO)

| Component | RTO | RPO | Recovery Method |
|-----------|-----|-----|-----------------|
| **Application** | 15 minutes | 0 (stateless) | Multi-AZ deployment |
| **Database** | 30 minutes | 5 minutes | Point-in-time recovery |
| **File Storage** | 5 minutes | 0 | S3 cross-region replication |
| **Complete System** | 1 hour | 15 minutes | Full DR procedure |

### Disaster Scenarios

#### Scenario 1: Single AZ Failure
```bash
# Automatic failover should occur
# Monitor failover status
aws rds describe-db-instances --db-instance-identifier propchain-prod-db

# If manual intervention needed
aws rds reboot-db-instance --db-instance-identifier propchain-prod-db --force-failover
```

#### Scenario 2: Region Failure
```bash
# Activate DR region
aws configure set default.region eu-west-1

# Restore database from cross-region backup
aws rds restore-db-instance-from-s3 \
  --db-instance-identifier propchain-dr-db \
  --db-instance-class db.r6g.large \
  --engine postgres \
  --s3-bucket-name propchain-backups-dr \
  --s3-prefix database-backups/

# Deploy application to DR region
kubectl config use-context dr-cluster
kubectl apply -f k8s/disaster-recovery/
```

#### Scenario 3: Complete Data Loss
```bash
# This is an extreme scenario requiring careful execution
# 1. Assess the extent of data loss
# 2. Identify the latest valid backup
# 3. Coordinate with business stakeholders
# 4. Execute full recovery procedure

# Create new environment
terraform apply -target=module.dr_environment

# Restore from latest backup
pg_restore -h $DR_DATABASE_HOST -U $DATABASE_USER -d $DATABASE_NAME latest_backup.dump

# Migrate DNS to DR environment
aws route53 change-resource-record-sets --hosted-zone-id Z123456789 --change-batch file://dns-failover.json
```

### DR Testing Schedule

#### Monthly Tests
- [ ] Backup restoration verification
- [ ] Application failover testing
- [ ] Database replica lag monitoring
- [ ] Cross-region sync verification

#### Quarterly Tests  
- [ ] Full DR environment activation
- [ ] End-to-end recovery procedure
- [ ] Performance validation in DR region
- [ ] Staff training and procedure review

#### Annual Tests
- [ ] Complete disaster simulation
- [ ] Business continuity validation
- [ ] RTO/RPO achievement verification
- [ ] DR plan updates and improvements

### Communication Plan

#### Internal Communication
1. **Immediate** (0-15 min): Ops team activation
2. **15 minutes**: Management notification
3. **30 minutes**: Development team briefing
4. **1 hour**: Business stakeholder update
5. **Ongoing**: Hourly status updates

#### External Communication
1. **30 minutes**: Status page update
2. **1 hour**: Customer notification email
3. **4 hours**: Detailed incident report
4. **24 hours**: Post-incident communication
5. **1 week**: Lessons learned publication

---

## Post-Incident Procedures

### Post-Mortem Process

#### Blameless Post-Mortem Template
```markdown
# Incident Post-Mortem: [INCIDENT_TITLE]

## Incident Summary
- **Date**: YYYY-MM-DD
- **Duration**: X hours Y minutes  
- **Impact**: [Description of impact]
- **Root Cause**: [Brief description]

## Timeline of Events
| Time (UTC) | Event | Action Taken | Person |
|------------|-------|--------------|---------|
| HH:MM | Issue detected | Investigation started | Name |
| HH:MM | Root cause identified | Fix implemented | Name |
| HH:MM | Service restored | Monitoring resumed | Name |

## What Went Well
- [Things that worked during the incident]
- [Good practices that helped]
- [Tools that were useful]

## What Didn't Go Well
- [Things that slowed down resolution]
- [Gaps in monitoring or alerting]
- [Process or documentation issues]

## Action Items
| Action | Owner | Due Date | Priority |
|--------|-------|----------|----------|
| Improve monitoring for X | DevOps | YYYY-MM-DD | High |
| Update runbook section Y | Dev Team | YYYY-MM-DD | Medium |
| Add automation for Z | Platform | YYYY-MM-DD | Low |

## Lessons Learned
- [Key insights from this incident]
- [How to prevent similar issues]
- [Process improvements needed]
```

#### Follow-up Actions
- Schedule post-mortem meeting within 48 hours
- Update runbooks and documentation
- Implement monitoring improvements  
- Share learnings with team and stakeholders
- Track action items to completion

### Continuous Improvement

#### Monthly Reviews
- Review all incidents and their resolution
- Analyze trends and patterns
- Update procedures and automation
- Conduct training on new processes

#### Quarterly Assessments
- Review and update all runbooks
- Validate DR procedures and RTOs
- Assess team skills and training needs
- Update monitoring and alerting rules

---

This completes the comprehensive runbooks for the Property Upkeep Records system. These procedures should be regularly tested, updated, and customized based on your specific environment and organizational needs.