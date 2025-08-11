# Property Upkeep Records System - Technical Specification

## Executive Summary

The Property Upkeep Records system is a comprehensive solution for tracking property maintenance, repairs, and improvements. This specification outlines a cloud-native, microservices-based architecture designed for multi-tenant operation with robust security, observability, and scalability features.

## System Overview

### Core Objectives
- Record and manage property upkeep jobs with full audit history
- Support multiple organizations with clear roles and permissions
- Provide REST APIs and responsive UI for all operations
- Enable reporting and data export capabilities

### Key Stakeholders
- **Property Owners/Landlords**: Full management access
- **Tenants/Requesters**: View history and submit requests
- **Auditors**: Read-only access to history and reports

## Architecture Blueprint

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet/Users                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                 Reverse Proxy (NGINX)                           │
│         • TLS Termination  • Rate Limiting                      │
│         • Request Logging  • Path-based Routing                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                Authentication Service                            │
│              • OIDC/OAuth2  • JWT Tokens                        │
│              • RBAC  • SSO Integration                          │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                   API Gateway                                   │
│              • Request Routing  • Validation                    │
│              • Rate Limiting    • Logging                       │
└─────────────┬───────────────────────────┬─────────────────────────┘
              │                           │
    ┌─────────▼──────────┐      ┌─────────▼──────────┐
    │    Core API        │      │   Reporting API    │
    │   Service          │      │     Service        │
    │                    │      │                    │
    └─────────┬──────────┘      └─────────┬──────────┘
              │                           │
┌─────────────▼───────────────────────────▼─────────────────────────┐
│                     Message Queue (AWS SQS)                      │
│        • Document Processing  • Image Thumbnailing               │
│        • Notifications       • Report Generation                 │
└─────────────┬───────────────────────────────────────────────────┘
              │
    ┌─────────▼──────────┐      ┌─────────▼──────────┐
    │   Background       │      │   Notification     │
    │    Workers         │      │     Service        │
    └─────────┬──────────┘      └─────────┬──────────┘
              │                           │
┌─────────────▼───────────────────────────▼─────────────────────────┐
│                    PostgreSQL Database                           │
│           • Multi-tenant with RLS  • Point-in-time Recovery      │
│           • Read Replicas          • Automated Backups           │
└───────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                   Observability Stack                            │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐   │
│   │ Prometheus  │  │  Grafana    │  │    Structured Logging   │   │
│   │  Metrics    │  │ Dashboards  │  │     (JSON + IDs)        │   │
│   └─────────────┘  └─────────────┘  └─────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
```

### Technology Stack

**Backend Services:**
- Language: Node.js/TypeScript or Python/FastAPI
- Framework: Express.js/Fastify or FastAPI
- Database: PostgreSQL 14+ with Row-Level Security
- Queue: AWS SQS with Dead Letter Queues
- Cache: Redis (optional, for sessions)

**Frontend:**
- Framework: React 18+ with TypeScript
- Styling: Tailwind CSS or Material-UI
- State Management: Redux Toolkit or Zustand
- Build Tool: Vite or Next.js

**Infrastructure:**
- Containerization: Docker with multi-stage builds
- Orchestration: Docker Compose (local), Kubernetes (production)
- Proxy: NGINX with SSL/TLS
- Monitoring: Prometheus + Grafana + AlertManager

**Cloud Services:**
- AWS SQS for messaging
- AWS S3 for document storage
- AWS Secrets Manager for secrets
- AWS RDS for PostgreSQL (or self-hosted)

## Domain Model

### Core Entities

```typescript
// Organization and User Management
interface Organisation {
  id: string;
  name: string;
  type: 'LANDLORD' | 'PROPERTY_MANAGEMENT' | 'OWNER';
  settings: OrganisationSettings;
  created_at: timestamp;
  updated_at: timestamp;
  deleted_at?: timestamp;
}

interface User {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone?: string;
  is_active: boolean;
  created_at: timestamp;
  updated_at: timestamp;
  deleted_at?: timestamp;
}

interface RoleAssignment {
  id: string;
  user_id: string;
  organisation_id: string;
  role: 'OWNER' | 'MANAGER' | 'TENANT' | 'AUDITOR';
  permissions: string[];
  created_at: timestamp;
  expires_at?: timestamp;
}

// Property and Asset Management
interface Property {
  id: string;
  organisation_id: string;
  address: Address;
  property_type: 'RESIDENTIAL' | 'COMMERCIAL' | 'MIXED_USE';
  metadata: PropertyMetadata;
  is_active: boolean;
  created_at: timestamp;
  updated_at: timestamp;
  deleted_at?: timestamp;
}

interface Asset {
  id: string;
  property_id: string;
  name: string;
  type: 'HVAC' | 'ELEVATOR' | 'PLUMBING' | 'ELECTRICAL' | 'OTHER';
  manufacturer?: string;
  model?: string;
  installation_date?: date;
  warranty_expires?: date;
  metadata: AssetMetadata;
  created_at: timestamp;
  updated_at: timestamp;
  deleted_at?: timestamp;
}

// Work and Maintenance Records
interface WorkLog {
  id: string;
  organisation_id: string; // for RLS
  property_id: string;
  asset_id?: string;
  title: string;
  description: text;
  category: 'MAINTENANCE' | 'REPAIR' | 'IMPROVEMENT' | 'INSPECTION';
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  status: 'PLANNED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
  assigned_to?: string; // user_id
  scheduled_date?: timestamp;
  completed_date?: timestamp;
  estimated_cost?: decimal;
  actual_cost?: decimal;
  notes?: text;
  created_by: string; // user_id
  created_at: timestamp;
  updated_at: timestamp;
  deleted_at?: timestamp;
  version: integer; // for optimistic locking
}

// Documents and Evidence
interface Document {
  id: string;
  organisation_id: string; // for RLS
  work_log_id?: string;
  property_id?: string;
  filename: string;
  original_filename: string;
  mime_type: string;
  file_size: integer;
  storage_path: string;
  document_type: 'PHOTO' | 'PDF' | 'TEXT' | 'VIDEO' | 'OTHER';
  metadata: DocumentMetadata;
  is_processed: boolean;
  created_by: string;
  created_at: timestamp;
  deleted_at?: timestamp;
}

interface Invoice {
  id: string;
  organisation_id: string; // for RLS
  work_log_id?: string;
  vendor_name: string;
  invoice_number: string;
  amount: decimal;
  tax_amount?: decimal;
  currency: string;
  invoice_date: date;
  due_date?: date;
  status: 'DRAFT' | 'PENDING' | 'PAID' | 'OVERDUE' | 'CANCELLED';
  payment_date?: date;
  created_at: timestamp;
  updated_at: timestamp;
  deleted_at?: timestamp;
}

// Audit and Notifications
interface AuditEvent {
  id: string;
  organisation_id: string; // for RLS
  entity_type: string;
  entity_id: string;
  action: 'CREATE' | 'UPDATE' | 'DELETE' | 'VIEW';
  user_id?: string;
  ip_address?: string;
  user_agent?: string;
  changes?: jsonb; // before/after values
  created_at: timestamp;
}

interface Notification {
  id: string;
  organisation_id: string; // for RLS
  user_id?: string;
  type: 'EMAIL' | 'SMS' | 'WEBHOOK';
  subject: string;
  content: text;
  recipient: string;
  status: 'PENDING' | 'SENT' | 'FAILED' | 'DELIVERED';
  scheduled_at?: timestamp;
  sent_at?: timestamp;
  metadata?: jsonb;
  created_at: timestamp;
}
```

### Database Schema Design

The system uses PostgreSQL with Row-Level Security (RLS) for multi-tenant isolation. Key design principles:

1. **Multi-tenancy**: Every table includes `organisation_id` for tenant isolation
2. **Soft Deletes**: Use `deleted_at` timestamp instead of hard deletes
3. **Audit Trail**: All changes tracked in `audit_events` table
4. **Optimistic Locking**: Version numbers for concurrent update handling
5. **Performance**: Strategic indexes on common query patterns

### Indexes Strategy

```sql
-- Performance-critical composite indexes
CREATE INDEX idx_work_logs_org_property ON work_logs(organisation_id, property_id);
CREATE INDEX idx_work_logs_status_date ON work_logs(status, scheduled_date);
CREATE INDEX idx_documents_work_log ON documents(work_log_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_audit_events_entity ON audit_events(entity_type, entity_id);
CREATE INDEX idx_notifications_user_status ON notifications(user_id, status);

-- Search and filtering indexes
CREATE INDEX idx_properties_address_gin ON properties USING gin(to_tsvector('english', address::text));
CREATE INDEX idx_work_logs_search_gin ON work_logs USING gin(to_tsvector('english', title || ' ' || description));
```

## API Specification

### Authentication Endpoints

```yaml
paths:
  /auth/login:
    post:
      summary: Authenticate user and return JWT tokens
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                email:
                  type: string
                  format: email
                password:
                  type: string
      responses:
        '200':
          description: Successful authentication
          content:
            application/json:
              schema:
                type: object
                properties:
                  access_token:
                    type: string
                  refresh_token:
                    type: string
                  expires_in:
                    type: integer
                  user:
                    $ref: '#/components/schemas/User'

  /auth/refresh:
    post:
      summary: Refresh access token
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                refresh_token:
                  type: string
      responses:
        '200':
          description: New access token
```

### Core API Endpoints

```yaml
paths:
  /api/v1/properties:
    get:
      summary: List properties for organization
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
        - name: search
          in: query
          schema:
            type: string
      responses:
        '200':
          description: List of properties
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Property'
                  pagination:
                    $ref: '#/components/schemas/Pagination'

    post:
      summary: Create new property
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/PropertyCreate'
      responses:
        '201':
          description: Property created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Property'

  /api/v1/properties/{propertyId}/work-logs:
    get:
      summary: List work logs for property
      parameters:
        - name: propertyId
          in: path
          required: true
          schema:
            type: string
        - name: status
          in: query
          schema:
            type: string
            enum: [PLANNED, IN_PROGRESS, COMPLETED, CANCELLED]
        - name: category
          in: query
          schema:
            type: string
            enum: [MAINTENANCE, REPAIR, IMPROVEMENT, INSPECTION]
        - name: from_date
          in: query
          schema:
            type: string
            format: date
        - name: to_date
          in: query
          schema:
            type: string
            format: date
      responses:
        '200':
          description: List of work logs

    post:
      summary: Create new work log
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/WorkLogCreate'
      responses:
        '201':
          description: Work log created

  /api/v1/work-logs/{workLogId}/documents:
    post:
      summary: Upload documents for work log
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                files:
                  type: array
                  items:
                    type: string
                    format: binary
                description:
                  type: string
      responses:
        '201':
          description: Documents uploaded

  /api/v1/reports/work-summary:
    get:
      summary: Generate work summary report
      parameters:
        - name: property_id
          in: query
          schema:
            type: string
        - name: from_date
          in: query
          schema:
            type: string
            format: date
        - name: to_date
          in: query
          schema:
            type: string
            format: date
        - name: format
          in: query
          schema:
            type: string
            enum: [json, csv]
            default: json
      responses:
        '200':
          description: Work summary report
```

## Security Architecture

### Authentication & Authorization

1. **OIDC/OAuth2 Integration**:
   - Support for Azure AD/Entra ID, Google, Auth0
   - PKCE flow for SPAs
   - Service-to-service authentication with client credentials

2. **JWT Token Strategy**:
   - Short-lived access tokens (15 minutes)
   - Long-lived refresh tokens (30 days)
   - Token rotation on refresh
   - Secure cookie storage for refresh tokens

3. **Role-Based Access Control (RBAC)**:
   ```typescript
   enum Role {
     OWNER = 'OWNER',           // Full access to organization data
     MANAGER = 'MANAGER',       // Manage properties and work logs
     TENANT = 'TENANT',         // View history, submit requests
     AUDITOR = 'AUDITOR'        // Read-only access to all data
   }

   const permissions = {
     OWNER: ['*'],
     MANAGER: ['properties:*', 'work-logs:*', 'reports:read'],
     TENANT: ['properties:read', 'work-logs:read', 'work-logs:create'],
     AUDITOR: ['*:read', 'reports:read']
   };
   ```

4. **Row-Level Security (RLS)**:
   ```sql
   -- Enable RLS on all tenant-specific tables
   ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
   ALTER TABLE work_logs ENABLE ROW LEVEL SECURITY;
   ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

   -- RLS policies for multi-tenant isolation
   CREATE POLICY properties_tenant_isolation ON properties
     USING (organisation_id = current_setting('app.current_organisation_id')::uuid);

   CREATE POLICY work_logs_tenant_isolation ON work_logs
     USING (organisation_id = current_setting('app.current_organisation_id')::uuid);
   ```

### Data Protection

1. **Encryption in Transit**:
   - TLS 1.2+ for all communications
   - HSTS headers
   - Certificate pinning for mobile apps

2. **Encryption at Rest**:
   - PostgreSQL transparent encryption
   - S3 bucket encryption with KMS keys
   - Encrypted database backups

3. **Input Validation**:
   - JSON Schema validation for all API inputs
   - SQL injection prevention with parameterized queries
   - XSS protection with CSP headers
   - File upload validation and scanning

### GDPR Compliance

1. **Data Retention Policies**:
   ```sql
   -- Automatic data purging after retention period
   CREATE OR REPLACE FUNCTION purge_old_data()
   RETURNS void AS $$
   BEGIN
     -- Soft delete old audit events (7 years retention)
     UPDATE audit_events 
     SET deleted_at = NOW() 
     WHERE created_at < NOW() - INTERVAL '7 years' 
       AND deleted_at IS NULL;
     
     -- Hard delete personal data after consent withdrawal
     DELETE FROM users 
     WHERE deleted_at < NOW() - INTERVAL '30 days';
   END;
   $$ LANGUAGE plpgsql;
   ```

2. **Right to Access/Erasure**:
   - API endpoints for data export
   - Automated data anonymization
   - Audit trail for data processing activities

## Queue Management & Event-Driven Architecture

### AWS SQS Configuration

```typescript
interface QueueConfig {
  documentProcessing: {
    queueName: 'property-upkeep-document-processing';
    visibilityTimeout: 300; // 5 minutes
    messageRetentionPeriod: 1209600; // 14 days
    maxReceiveCount: 3;
    deadLetterQueue: 'property-upkeep-document-processing-dlq';
  };
  
  notifications: {
    queueName: 'property-upkeep-notifications';
    visibilityTimeout: 60; // 1 minute
    messageRetentionPeriod: 86400; // 1 day
    maxReceiveCount: 5;
    deadLetterQueue: 'property-upkeep-notifications-dlq';
  };
  
  reportGeneration: {
    queueName: 'property-upkeep-reports';
    visibilityTimeout: 1800; // 30 minutes
    messageRetentionPeriod: 259200; // 3 days
    maxReceiveCount: 2;
    deadLetterQueue: 'property-upkeep-reports-dlq';
  };
}
```

### Message Processing

```typescript
interface WorkLogCreatedEvent {
  eventType: 'WORK_LOG_CREATED';
  workLogId: string;
  organisationId: string;
  propertyId: string;
  createdBy: string;
  timestamp: string;
  idempotencyKey: string;
}

interface DocumentUploadedEvent {
  eventType: 'DOCUMENT_UPLOADED';
  documentId: string;
  workLogId: string;
  filename: string;
  mimeType: string;
  fileSize: number;
  processingRequired: boolean;
  idempotencyKey: string;
}

// Idempotent message processing
class MessageProcessor {
  async processMessage(message: SQSMessage): Promise<void> {
    const idempotencyKey = message.body.idempotencyKey;
    
    // Check if already processed
    const existing = await this.getProcessedMessage(idempotencyKey);
    if (existing) {
      return; // Already processed, skip
    }
    
    try {
      await this.handleMessage(message);
      await this.markAsProcessed(idempotencyKey);
    } catch (error) {
      await this.handleProcessingError(message, error);
      throw error; // Will trigger retry or DLQ
    }
  }
}
```

## Observability & Monitoring

### Prometheus Metrics

```yaml
# Application metrics
http_requests_total:
  type: counter
  labels: [method, endpoint, status_code]
  description: Total HTTP requests

http_request_duration_seconds:
  type: histogram
  labels: [method, endpoint]
  description: HTTP request duration

database_connections_active:
  type: gauge
  description: Active database connections

queue_messages_pending:
  type: gauge
  labels: [queue_name]
  description: Pending messages in queue

document_processing_duration_seconds:
  type: histogram
  labels: [document_type]
  description: Document processing time

work_logs_created_total:
  type: counter
  labels: [organisation_id, category]
  description: Total work logs created

# Infrastructure metrics
container_memory_usage_bytes:
  type: gauge
  labels: [container_name]
  description: Container memory usage

container_cpu_usage_percent:
  type: gauge
  labels: [container_name]
  description: Container CPU usage percentage
```

### Grafana Dashboards

1. **API Performance Dashboard**:
   - Request rate and response times (P50, P95, P99)
   - Error rates by endpoint
   - Top slowest endpoints
   - Concurrent users

2. **Business Metrics Dashboard**:
   - Work logs created per day/month
   - Properties managed per organization
   - Document upload statistics
   - User activity metrics

3. **Infrastructure Dashboard**:
   - Container resource usage
   - Database performance metrics
   - Queue depth and processing rates
   - SSL certificate expiration alerts

### Alerting Rules

```yaml
groups:
  - name: api_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} requests/sec"

      - alert: SlowResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.3
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Slow response time"
          description: "95th percentile response time is {{ $value }}s"

  - name: queue_alerts
    rules:
      - alert: QueueBacklog
        expr: queue_messages_pending > 100
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Queue backlog detected"
          description: "{{ $labels.queue_name }} has {{ $value }} pending messages"

  - name: database_alerts
    rules:
      - alert: DatabaseConnections
        expr: database_connections_active > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High database connection usage"
          description: "{{ $value }} active connections"
```

## Deployment Strategy

### Development Environment

```yaml
# docker-compose.yml
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - api
      - frontend

  api:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://user:pass@postgres:5432/property_upkeep
      - SQS_ENDPOINT=http://localstack:4566
      - REDIS_URL=redis://redis:6379
    volumes:
      - ./backend:/app
      - /app/node_modules
    depends_on:
      - postgres
      - redis
      - localstack

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    volumes:
      - ./frontend:/app
      - /app/node_modules
    environment:
      - REACT_APP_API_BASE_URL=http://localhost/api

  postgres:
    image: postgres:14-alpine
    environment:
      - POSTGRES_DB=property_upkeep
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  localstack:
    image: localstack/localstack:latest
    environment:
      - SERVICES=sqs,s3
      - DATA_DIR=/tmp/localstack/data
    volumes:
      - localstack_data:/tmp/localstack
    ports:
      - "4566:4566"

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
    ports:
      - "3000:3000"

volumes:
  postgres_data:
  localstack_data:
  prometheus_data:
  grafana_data:
```

### Production Deployment (Kubernetes Ready)

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: property-upkeep
  labels:
    name: property-upkeep

---
# k8s/api-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: property-upkeep-api
  namespace: property-upkeep
spec:
  replicas: 3
  selector:
    matchLabels:
      app: property-upkeep-api
  template:
    metadata:
      labels:
        app: property-upkeep-api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: api
        image: property-upkeep/api:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: jwt-credentials
              key: secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'

    - name: Install dependencies
      run: |
        npm ci
        cd frontend && npm ci

    - name: Run linting
      run: |
        npm run lint
        cd frontend && npm run lint

    - name: Run tests
      run: |
        npm run test:unit
        npm run test:integration
        cd frontend && npm run test

    - name: Run security audit
      run: |
        npm audit --audit-level high
        cd frontend && npm audit --audit-level high

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push'

    steps:
    - uses: actions/checkout@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2

    - name: Login to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ secrets.REGISTRY_URL }}
        username: ${{ secrets.REGISTRY_USERNAME }}
        password: ${{ secrets.REGISTRY_PASSWORD }}

    - name: Build and push API image
      uses: docker/build-push-action@v4
      with:
        context: ./backend
        push: true
        tags: |
          ${{ secrets.REGISTRY_URL }}/property-upkeep/api:${{ github.sha }}
          ${{ secrets.REGISTRY_URL }}/property-upkeep/api:latest
        cache-from: type=gha
        cache-to: type=gha,mode=max

    - name: Build and push Frontend image
      uses: docker/build-push-action@v4
      with:
        context: ./frontend
        push: true
        tags: |
          ${{ secrets.REGISTRY_URL }}/property-upkeep/frontend:${{ github.sha }}
          ${{ secrets.REGISTRY_URL }}/property-upkeep/frontend:latest
        cache-from: type=gha
        cache-to: type=gha,mode=max

    - name: Generate SBOM
      uses: anchore/sbom-action@v0
      with:
        image: ${{ secrets.REGISTRY_URL }}/property-upkeep/api:${{ github.sha }}
        format: spdx-json
        output-file: sbom.spdx.json

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
    - uses: actions/checkout@v3

    - name: Deploy to staging
      run: |
        # Update Kubernetes manifests with new image tags
        sed -i 's|image: property-upkeep/api:.*|image: ${{ secrets.REGISTRY_URL }}/property-upkeep/api:${{ github.sha }}|' k8s/api-deployment.yaml
        sed -i 's|image: property-upkeep/frontend:.*|image: ${{ secrets.REGISTRY_URL }}/property-upkeep/frontend:${{ github.sha }}|' k8s/frontend-deployment.yaml
        
        # Apply to staging
        kubectl apply -f k8s/ --namespace=property-upkeep-staging

    - name: Run smoke tests
      run: |
        npm run test:e2e:staging

    - name: Deploy to production
      if: success()
      run: |
        kubectl apply -f k8s/ --namespace=property-upkeep-prod
        kubectl rollout status deployment/property-upkeep-api --namespace=property-upkeep-prod
```

## Testing Strategy

### Testing Pyramid

```typescript
// Unit Tests (70% coverage target)
describe('WorkLogService', () => {
  let service: WorkLogService;
  let mockRepository: jest.Mocked<WorkLogRepository>;

  beforeEach(() => {
    mockRepository = createMockRepository();
    service = new WorkLogService(mockRepository);
  });

  it('should create work log with audit trail', async () => {
    const workLogData = createMockWorkLogData();
    const expectedWorkLog = createMockWorkLog();
    
    mockRepository.create.mockResolvedValue(expectedWorkLog);

    const result = await service.createWorkLog(workLogData);

    expect(result).toEqual(expectedWorkLog);
    expect(mockRepository.create).toHaveBeenCalledWith(workLogData);
    expect(mockRepository.createAuditEvent).toHaveBeenCalledWith({
      entityType: 'WORK_LOG',
      entityId: expectedWorkLog.id,
      action: 'CREATE',
      userId: workLogData.createdBy
    });
  });
});

// Integration Tests (20% coverage target)
describe('Work Log API Integration', () => {
  let app: Application;
  let db: Database;

  beforeAll(async () => {
    app = await createTestApp();
    db = await createTestDatabase();
  });

  afterAll(async () => {
    await db.close();
  });

  beforeEach(async () => {
    await db.seed();
  });

  it('should create work log and process documents', async () => {
    const authToken = await getTestAuthToken('manager');
    
    const response = await request(app)
      .post('/api/v1/properties/test-property-id/work-logs')
      .set('Authorization', `Bearer ${authToken}`)
      .field('title', 'Test Work Log')
      .field('description', 'Test Description')
      .field('category', 'MAINTENANCE')
      .attach('documents', 'test-files/sample.pdf')
      .expect(201);

    expect(response.body.title).toBe('Test Work Log');
    
    // Verify document was queued for processing
    const queueMessages = await getQueueMessages('document-processing');
    expect(queueMessages).toHaveLength(1);
    expect(queueMessages[0].documentId).toBeDefined();
  });
});

// Contract Tests
describe('API Contract Tests', () => {
  it('should match OpenAPI specification', async () => {
    const spec = await loadOpenAPISpec();
    const validator = new OpenAPIValidator(spec);
    
    const response = await request(app)
      .get('/api/v1/properties')
      .set('Authorization', `Bearer ${validToken}`)
      .expect(200);

    const validation = validator.validateResponse(response);
    expect(validation.errors).toHaveLength(0);
  });
});

// E2E Tests (10% coverage target)
describe('Property Management E2E', () => {
  it('should complete full work log workflow', async () => {
    // Login as property manager
    await page.goto('/login');
    await page.fill('[data-testid=email]', 'manager@test.com');
    await page.fill('[data-testid=password]', 'password');
    await page.click('[data-testid=login-button]');

    // Navigate to property
    await page.click('[data-testid=properties-menu]');
    await page.click('[data-testid=property-123]');

    // Create work log
    await page.click('[data-testid=new-work-log]');
    await page.fill('[data-testid=title]', 'Fix broken faucet');
    await page.selectOption('[data-testid=category]', 'REPAIR');
    await page.click('[data-testid=save-work-log]');

    // Verify work log appears in list
    await expect(page.locator('[data-testid=work-log-item]')).toContainText('Fix broken faucet');

    // Upload document
    await page.click('[data-testid=upload-document]');
    await page.setInputFiles('[data-testid=file-input]', 'test-files/before-photo.jpg');
    await page.click('[data-testid=upload-button]');

    // Verify document uploaded
    await expect(page.locator('[data-testid=document-list]')).toContainText('before-photo.jpg');
  });
});
```

## Phased Delivery Plan

### Phase 1: MVP (8-10 weeks)

**Core Features:**
- User authentication and basic RBAC
- Property management (CRUD)
- Work log management with basic workflow
- Document upload and storage
- Simple reporting (work log list/export)
- Basic audit trail

**Technical Implementation:**
- Single deployable application (monolith)
- PostgreSQL database with RLS
- File storage in local filesystem/S3
- Basic Docker containers
- Simple CI/CD pipeline

**Acceptance Criteria:**
- Property managers can create and manage properties
- Work logs can be created, updated, and marked complete
- Documents can be uploaded and associated with work logs
- Basic reporting available via CSV export
- Multi-tenant isolation working correctly

### Phase 2: Production Ready (4-6 weeks)

**Enhanced Features:**
- Advanced search and filtering
- Notification system (email/SMS)
- Enhanced reporting and analytics
- Asset management
- Invoice tracking
- Improved UI/UX

**Technical Enhancements:**
- Microservices architecture
- AWS SQS for async processing
- Redis for caching and sessions
- Comprehensive monitoring with Prometheus/Grafana
- Automated testing pipeline
- Performance optimization

**Acceptance Criteria:**
- System handles 1000+ concurrent users
- P95 response time < 300ms
- 99.9% uptime SLA
- Comprehensive monitoring and alerting
- Full backup and recovery procedures

### Phase 3: Kubernetes Migration (3-4 weeks)

**Infrastructure Migration:**
- Kubernetes deployment manifests
- Helm charts for easy deployment
- Service mesh implementation (optional)
- Auto-scaling policies
- Advanced monitoring and observability

**Advanced Features:**
- Real-time notifications via WebSocket
- Advanced analytics and dashboards
- Mobile app APIs
- Third-party integrations
- Advanced security features

**Acceptance Criteria:**
- System runs reliably on Kubernetes
- Auto-scaling based on load
- Zero-downtime deployments
- Advanced observability and debugging capabilities
- Ready for multi-region deployment

## Risk Assessment & Mitigation

### Technical Risks

1. **Database Performance at Scale**
   - Risk: PostgreSQL performance degradation with large datasets
   - Mitigation: Read replicas, query optimization, proper indexing strategy

2. **Queue Processing Bottlenecks**
   - Risk: Document processing queue backing up
   - Mitigation: Auto-scaling workers, DLQ monitoring, processing optimization

3. **Security Vulnerabilities**
   - Risk: Data breaches or unauthorized access
   - Mitigation: Regular security audits, automated vulnerability scanning, RBAC enforcement

### Operational Risks

1. **Data Loss**
   - Risk: Critical data loss due to failures
   - Mitigation: Automated backups, point-in-time recovery, tested restore procedures

2. **Service Downtime**
   - Risk: Extended outages affecting users
   - Mitigation: High availability deployment, health checks, automated failover

3. **Compliance Issues**
   - Risk: GDPR or other regulatory violations
   - Mitigation: Privacy by design, regular compliance audits, data retention policies

## Success Metrics

### Business Metrics
- Time to create property record: < 2 minutes
- Time to complete work log entry: < 5 minutes
- User satisfaction score: > 4.0/5.0
- Data accuracy (audit compliance): > 99%

### Technical Metrics
- API response time (P95): < 300ms
- System uptime: > 99.9%
- Error rate: < 0.1%
- Queue processing time: < 30 seconds average

### Operational Metrics
- Deployment frequency: Daily (after Phase 2)
- Lead time for changes: < 1 day
- Mean time to recovery: < 1 hour
- Change failure rate: < 5%

## Conclusion

This technical specification provides a comprehensive blueprint for building a robust, scalable Property Upkeep Records system. The architecture follows cloud-native principles with strong security, observability, and operational practices.

The phased delivery approach ensures rapid time-to-value while building toward a production-ready, enterprise-grade solution. The emphasis on automation, monitoring, and maintainability will ensure the system can evolve and scale with business requirements.

Key success factors:
- Adherence to the architectural blueprint
- Comprehensive testing at all levels
- Strong DevOps practices and automation
- Continuous monitoring and improvement
- Security and compliance from day one

Next steps involve detailed implementation planning for Phase 1 MVP, including sprint planning, resource allocation, and risk mitigation strategies.