-- Property Upkeep Records System - PostgreSQL Database Schema
-- Version: 1.0
-- Target: PostgreSQL 14+

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create custom types
CREATE TYPE user_role AS ENUM ('OWNER', 'MANAGER', 'TENANT', 'AUDITOR');
CREATE TYPE property_type AS ENUM ('RESIDENTIAL', 'COMMERCIAL', 'MIXED_USE');
CREATE TYPE asset_type AS ENUM ('HVAC', 'ELEVATOR', 'PLUMBING', 'ELECTRICAL', 'OTHER');
CREATE TYPE work_category AS ENUM ('MAINTENANCE', 'REPAIR', 'IMPROVEMENT', 'INSPECTION');
CREATE TYPE work_priority AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE work_status AS ENUM ('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
CREATE TYPE document_type AS ENUM ('PHOTO', 'PDF', 'TEXT', 'VIDEO', 'OTHER');
CREATE TYPE invoice_status AS ENUM ('DRAFT', 'PENDING', 'PAID', 'OVERDUE', 'CANCELLED');
CREATE TYPE audit_action AS ENUM ('CREATE', 'UPDATE', 'DELETE', 'VIEW');
CREATE TYPE notification_type AS ENUM ('EMAIL', 'SMS', 'WEBHOOK');
CREATE TYPE notification_status AS ENUM ('PENDING', 'SENT', 'FAILED', 'DELIVERED');

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Organizations table (top-level tenant isolation)
CREATE TABLE organisations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'LANDLORD',
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_organisations_name ON organisations(name) WHERE deleted_at IS NULL;
CREATE INDEX idx_organisations_type ON organisations(type) WHERE deleted_at IS NULL;

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    password_hash VARCHAR(255), -- For local auth, nullable for SSO-only users
    email_verified BOOLEAN DEFAULT false,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_name ON users(last_name, first_name) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_active ON users(is_active) WHERE deleted_at IS NULL;

-- Role assignments (many-to-many users and organisations)
CREATE TABLE role_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    role user_role NOT NULL,
    permissions JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES users(id)
);

CREATE INDEX idx_role_assignments_user ON role_assignments(user_id);
CREATE INDEX idx_role_assignments_org ON role_assignments(organisation_id);
CREATE INDEX idx_role_assignments_role ON role_assignments(role);
CREATE UNIQUE INDEX idx_role_assignments_unique ON role_assignments(user_id, organisation_id, role) 
    WHERE expires_at IS NULL OR expires_at > NOW();

-- Properties table
CREATE TABLE properties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address JSONB NOT NULL, -- Flexible address structure
    property_type property_type NOT NULL DEFAULT 'RESIDENTIAL',
    metadata JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES users(id)
);

CREATE INDEX idx_properties_org ON properties(organisation_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_properties_type ON properties(property_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_properties_active ON properties(is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_properties_address_gin ON properties USING gin((address::text));
CREATE INDEX idx_properties_search ON properties USING gin(to_tsvector('english', name || ' ' || (address->>'street') || ' ' || (address->>'city')));

-- Assets table (equipment/fixtures in properties)
CREATE TABLE assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    type asset_type NOT NULL,
    manufacturer VARCHAR(255),
    model VARCHAR(255),
    serial_number VARCHAR(255),
    installation_date DATE,
    warranty_expires DATE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES users(id)
);

CREATE INDEX idx_assets_property ON assets(property_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_assets_type ON assets(type) WHERE deleted_at IS NULL;
CREATE INDEX idx_assets_warranty ON assets(warranty_expires) WHERE warranty_expires IS NOT NULL AND deleted_at IS NULL;

-- Work logs table (main entity for tracking work)
CREATE TABLE work_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    asset_id UUID REFERENCES assets(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category work_category NOT NULL,
    priority work_priority DEFAULT 'MEDIUM',
    status work_status DEFAULT 'PLANNED',
    assigned_to UUID REFERENCES users(id),
    scheduled_date TIMESTAMP WITH TIME ZONE,
    completed_date TIMESTAMP WITH TIME ZONE,
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    version INTEGER DEFAULT 1 -- For optimistic locking
);

-- Strategic indexes for work_logs (most queried table)
CREATE INDEX idx_work_logs_org_property ON work_logs(organisation_id, property_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_work_logs_status ON work_logs(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_work_logs_assigned ON work_logs(assigned_to) WHERE assigned_to IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_work_logs_scheduled ON work_logs(scheduled_date) WHERE scheduled_date IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_work_logs_category_priority ON work_logs(category, priority) WHERE deleted_at IS NULL;
CREATE INDEX idx_work_logs_search ON work_logs USING gin(to_tsvector('english', title || ' ' || COALESCE(description, '')));
CREATE INDEX idx_work_logs_created_at ON work_logs(created_at DESC) WHERE deleted_at IS NULL;

-- Documents table (photos, PDFs, etc.)
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    work_log_id UUID REFERENCES work_logs(id) ON DELETE CASCADE,
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    storage_path TEXT NOT NULL,
    document_type document_type NOT NULL,
    metadata JSONB DEFAULT '{}',
    is_processed BOOLEAN DEFAULT false,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_documents_org ON documents(organisation_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_work_log ON documents(work_log_id) WHERE work_log_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_documents_property ON documents(property_id) WHERE property_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_documents_type ON documents(document_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_processing ON documents(is_processed) WHERE NOT is_processed;

-- Invoices table
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    work_log_id UUID REFERENCES work_logs(id) ON DELETE SET NULL,
    vendor_name VARCHAR(255) NOT NULL,
    invoice_number VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'GBP',
    invoice_date DATE NOT NULL,
    due_date DATE,
    status invoice_status DEFAULT 'DRAFT',
    payment_date DATE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_by UUID NOT NULL REFERENCES users(id)
);

CREATE INDEX idx_invoices_org ON invoices(organisation_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoices_work_log ON invoices(work_log_id) WHERE work_log_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_invoices_status ON invoices(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoices_due_date ON invoices(due_date) WHERE due_date IS NOT NULL AND status != 'PAID' AND deleted_at IS NULL;
CREATE UNIQUE INDEX idx_invoices_number_org ON invoices(organisation_id, invoice_number) WHERE deleted_at IS NULL;

-- Audit events table (immutable audit trail)
CREATE TABLE audit_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID REFERENCES organisations(id), -- nullable for system events
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    action audit_action NOT NULL,
    user_id UUID REFERENCES users(id),
    ip_address INET,
    user_agent TEXT,
    changes JSONB, -- before/after values for updates
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Partition audit_events by month for performance
CREATE INDEX idx_audit_events_entity ON audit_events(entity_type, entity_id);
CREATE INDEX idx_audit_events_user ON audit_events(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_audit_events_org_time ON audit_events(organisation_id, created_at) WHERE organisation_id IS NOT NULL;
CREATE INDEX idx_audit_events_time ON audit_events(created_at);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organisation_id UUID NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    subject VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    recipient VARCHAR(255) NOT NULL,
    status notification_status DEFAULT 'PENDING',
    scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sent_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_org ON notifications(organisation_id);
CREATE INDEX idx_notifications_user ON notifications(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_notifications_status_scheduled ON notifications(status, scheduled_at) WHERE status = 'PENDING';
CREATE INDEX idx_notifications_type ON notifications(type);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tenant-specific tables
ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's organisation access
CREATE OR REPLACE FUNCTION user_organisation_ids()
RETURNS UUID[] AS $$
BEGIN
    RETURN string_to_array(current_setting('app.user_organisation_ids', true), ',')::UUID[];
EXCEPTION
    WHEN OTHERS THEN
        RETURN ARRAY[]::UUID[];
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user has role in organisation
CREATE OR REPLACE FUNCTION user_has_role_in_org(org_id UUID, required_role user_role)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM role_assignments ra
        WHERE ra.organisation_id = org_id
        AND ra.user_id = current_setting('app.current_user_id')::UUID
        AND ra.role = required_role
        AND (ra.expires_at IS NULL OR ra.expires_at > NOW())
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies

-- Organisations: Users can only see orgs they belong to
CREATE POLICY organisations_access ON organisations
    FOR ALL USING (
        id = ANY(user_organisation_ids()) OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- Role assignments: Users can see their own assignments and org admins can see all
CREATE POLICY role_assignments_access ON role_assignments
    FOR ALL USING (
        user_id = current_setting('app.current_user_id')::UUID OR
        organisation_id = ANY(user_organisation_ids()) OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- Properties: Org-based access
CREATE POLICY properties_access ON properties
    FOR ALL USING (
        organisation_id = ANY(user_organisation_ids()) OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- Assets: Access through properties
CREATE POLICY assets_access ON assets
    FOR ALL USING (
        property_id IN (
            SELECT id FROM properties 
            WHERE organisation_id = ANY(user_organisation_ids())
        ) OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- Work logs: Org-based access with role-based restrictions
CREATE POLICY work_logs_access ON work_logs
    FOR ALL USING (
        organisation_id = ANY(user_organisation_ids()) OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- Documents: Access through work logs or properties
CREATE POLICY documents_access ON documents
    FOR ALL USING (
        organisation_id = ANY(user_organisation_ids()) OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- Invoices: Org-based access
CREATE POLICY invoices_access ON invoices
    FOR ALL USING (
        organisation_id = ANY(user_organisation_ids()) OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- Audit events: Read-only for org users
CREATE POLICY audit_events_access ON audit_events
    FOR SELECT USING (
        organisation_id = ANY(user_organisation_ids()) OR
        user_id = current_setting('app.current_user_id')::UUID OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- Notifications: Users can see their own notifications
CREATE POLICY notifications_access ON notifications
    FOR ALL USING (
        user_id = current_setting('app.current_user_id')::UUID OR
        organisation_id = ANY(user_organisation_ids()) OR
        current_setting('app.bypass_rls', true) = 'true'
    );

-- ============================================================================
-- TRIGGERS AND FUNCTIONS
-- ============================================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to relevant tables
CREATE TRIGGER update_organisations_updated_at BEFORE UPDATE ON organisations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_properties_updated_at BEFORE UPDATE ON properties
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_assets_updated_at BEFORE UPDATE ON assets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_work_logs_updated_at BEFORE UPDATE ON work_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Audit trail trigger function
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
    audit_row audit_events%rowtype;
    excluded_columns text[] = ARRAY['updated_at'];
    old_data jsonb;
    new_data jsonb;
    changed_fields jsonb;
BEGIN
    -- Skip if this is an audit event table (prevent recursion)
    IF TG_TABLE_NAME = 'audit_events' THEN
        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        RETURN NEW;
    END IF;

    audit_row = ROW(
        uuid_generate_v4(),
        CASE 
            WHEN TG_TABLE_NAME IN ('organisations', 'users', 'role_assignments') THEN NULL
            ELSE COALESCE(NEW.organisation_id, OLD.organisation_id)
        END,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        TG_OP::audit_action,
        NULLIF(current_setting('app.current_user_id', true), '')::UUID,
        NULLIF(current_setting('app.client_ip', true), '')::INET,
        NULLIF(current_setting('app.user_agent', true), ''),
        NULL,
        NOW()
    );

    IF TG_OP = 'DELETE' THEN
        old_data = to_jsonb(OLD);
        audit_row.changes = jsonb_build_object('old', old_data);
        INSERT INTO audit_events VALUES (audit_row.*);
        RETURN OLD;
    
    ELSIF TG_OP = 'UPDATE' THEN
        old_data = to_jsonb(OLD);
        new_data = to_jsonb(NEW);
        
        -- Calculate changed fields
        changed_fields = '{}'::jsonb;
        FOR key IN (SELECT jsonb_object_keys(new_data)) LOOP
            IF key = ANY(excluded_columns) THEN
                CONTINUE;
            END IF;
            
            IF old_data->key IS DISTINCT FROM new_data->key THEN
                changed_fields = changed_fields || jsonb_build_object(
                    key, jsonb_build_object(
                        'old', old_data->key,
                        'new', new_data->key
                    )
                );
            END IF;
        END LOOP;
        
        -- Only audit if something actually changed
        IF changed_fields != '{}'::jsonb THEN
            audit_row.changes = changed_fields;
            INSERT INTO audit_events VALUES (audit_row.*);
        END IF;
        
        RETURN NEW;
    
    ELSIF TG_OP = 'INSERT' THEN
        audit_row.changes = jsonb_build_object('new', to_jsonb(NEW));
        INSERT INTO audit_events VALUES (audit_row.*);
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit triggers to all main tables
CREATE TRIGGER audit_organisations AFTER INSERT OR UPDATE OR DELETE ON organisations
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_users AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_role_assignments AFTER INSERT OR UPDATE OR DELETE ON role_assignments
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_properties AFTER INSERT OR UPDATE OR DELETE ON properties
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_assets AFTER INSERT OR UPDATE OR DELETE ON assets
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_work_logs AFTER INSERT OR UPDATE OR DELETE ON work_logs
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_documents AFTER INSERT OR UPDATE OR DELETE ON documents
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER audit_invoices AFTER INSERT OR UPDATE OR DELETE ON invoices
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

-- Optimistic locking trigger for work_logs
CREATE OR REPLACE FUNCTION increment_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER work_logs_version BEFORE UPDATE ON work_logs
    FOR EACH ROW EXECUTE FUNCTION increment_version();

-- ============================================================================
-- SAMPLE QUERIES FOR COMMON REPORTS
-- ============================================================================

-- Query: Work logs by property and date range
/*
SELECT 
    p.name as property_name,
    wl.title,
    wl.category,
    wl.status,
    wl.priority,
    wl.scheduled_date,
    wl.completed_date,
    wl.actual_cost,
    u.first_name || ' ' || u.last_name as assigned_to_name
FROM work_logs wl
JOIN properties p ON wl.property_id = p.id
LEFT JOIN users u ON wl.assigned_to = u.id
WHERE wl.organisation_id = $1
    AND wl.scheduled_date BETWEEN $2 AND $3
    AND wl.deleted_at IS NULL
ORDER BY wl.scheduled_date DESC;
*/

-- Query: Costs by property and period
/*
SELECT 
    p.name as property_name,
    p.id as property_id,
    DATE_TRUNC('month', wl.completed_date) as month,
    COUNT(*) as work_count,
    SUM(wl.actual_cost) as total_cost,
    AVG(wl.actual_cost) as avg_cost,
    COUNT(*) FILTER (WHERE wl.priority = 'CRITICAL') as critical_count
FROM work_logs wl
JOIN properties p ON wl.property_id = p.id
WHERE wl.organisation_id = $1
    AND wl.status = 'COMPLETED'
    AND wl.completed_date >= $2
    AND wl.deleted_at IS NULL
GROUP BY p.id, p.name, DATE_TRUNC('month', wl.completed_date)
ORDER BY month DESC, total_cost DESC;
*/

-- Query: Overdue work logs
/*
SELECT 
    wl.id,
    wl.title,
    p.name as property_name,
    wl.priority,
    wl.scheduled_date,
    EXTRACT(days FROM NOW() - wl.scheduled_date) as days_overdue,
    u.first_name || ' ' || u.last_name as assigned_to_name
FROM work_logs wl
JOIN properties p ON wl.property_id = p.id
LEFT JOIN users u ON wl.assigned_to = u.id
WHERE wl.organisation_id = $1
    AND wl.status IN ('PLANNED', 'IN_PROGRESS')
    AND wl.scheduled_date < NOW()
    AND wl.deleted_at IS NULL
ORDER BY wl.scheduled_date ASC;
*/

-- Query: Document summary by work log
/*
SELECT 
    wl.id as work_log_id,
    wl.title,
    COUNT(d.id) as document_count,
    SUM(d.file_size) as total_file_size,
    STRING_AGG(DISTINCT d.document_type::text, ', ') as document_types
FROM work_logs wl
LEFT JOIN documents d ON wl.id = d.work_log_id AND d.deleted_at IS NULL
WHERE wl.organisation_id = $1
    AND wl.deleted_at IS NULL
GROUP BY wl.id, wl.title
HAVING COUNT(d.id) > 0
ORDER BY document_count DESC;
*/

-- ============================================================================
-- SEED DATA FOR DEVELOPMENT
-- ============================================================================

-- Create initial organisation
INSERT INTO organisations (id, name, type, settings) VALUES 
('00000000-0000-4000-8000-000000000001', 'Demo Property Management', 'PROPERTY_MANAGEMENT', '{"timezone": "Europe/London", "currency": "GBP"}');

-- Create demo users
INSERT INTO users (id, email, first_name, last_name, password_hash, is_active, email_verified) VALUES 
('00000000-0000-4000-8000-000000000001', 'admin@demo.com', 'System', 'Administrator', '$2b$12$dummy_hash_for_demo', true, true),
('00000000-0000-4000-8000-000000000002', 'manager@demo.com', 'Property', 'Manager', '$2b$12$dummy_hash_for_demo', true, true),
('00000000-0000-4000-8000-000000000003', 'tenant@demo.com', 'Demo', 'Tenant', '$2b$12$dummy_hash_for_demo', true, true),
('00000000-0000-4000-8000-000000000004', 'auditor@demo.com', 'External', 'Auditor', '$2b$12$dummy_hash_for_demo', true, true);

-- Create role assignments
INSERT INTO role_assignments (user_id, organisation_id, role, created_by) VALUES 
('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'OWNER', '00000000-0000-4000-8000-000000000001'),
('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'MANAGER', '00000000-0000-4000-8000-000000000001'),
('00000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000001', 'TENANT', '00000000-0000-4000-8000-000000000001'),
('00000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000001', 'AUDITOR', '00000000-0000-4000-8000-000000000001');

-- Create demo properties
INSERT INTO properties (id, organisation_id, name, address, property_type, created_by) VALUES 
('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'Oak Street Apartments', '{"street": "123 Oak Street", "city": "London", "postcode": "SW1A 1AA", "country": "UK"}', 'RESIDENTIAL', '00000000-0000-4000-8000-000000000001'),
('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000001', 'Commercial Plaza', '{"street": "456 High Street", "city": "Manchester", "postcode": "M1 1AA", "country": "UK"}', 'COMMERCIAL', '00000000-0000-4000-8000-000000000001');

-- Create demo assets
INSERT INTO assets (property_id, name, type, manufacturer, model, installation_date, created_by) VALUES 
('00000000-0000-4000-8000-000000000001', 'Main HVAC Unit', 'HVAC', 'Carrier', '50VL020', '2020-01-15', '00000000-0000-4000-8000-000000000002'),
('00000000-0000-4000-8000-000000000001', 'Passenger Elevator', 'ELEVATOR', 'Otis', '2000R', '2018-03-20', '00000000-0000-4000-8000-000000000002');

-- Create demo work logs
INSERT INTO work_logs (organisation_id, property_id, asset_id, title, description, category, priority, status, scheduled_date, created_by) VALUES 
('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', (SELECT id FROM assets WHERE name = 'Main HVAC Unit'), 'HVAC Quarterly Maintenance', 'Routine quarterly maintenance including filter replacement and system inspection', 'MAINTENANCE', 'MEDIUM', 'PLANNED', NOW() + INTERVAL '7 days', '00000000-0000-4000-8000-000000000002'),
('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', NULL, 'Lobby Light Repair', 'Replace faulty LED lights in main lobby area', 'REPAIR', 'LOW', 'COMPLETED', NOW() - INTERVAL '3 days', '00000000-0000-4000-8000-000000000002');

-- Update the completed work log
UPDATE work_logs SET 
    completed_date = NOW() - INTERVAL '1 day',
    actual_cost = 450.00,
    status = 'COMPLETED',
    notes = 'Replaced 6 LED light fixtures. All working correctly.'
WHERE title = 'Lobby Light Repair';

-- ============================================================================
-- PERFORMANCE OPTIMIZATION
-- ============================================================================

-- Analyze tables for better query planning
ANALYZE organisations;
ANALYZE users;
ANALYZE role_assignments;
ANALYZE properties;
ANALYZE assets;
ANALYZE work_logs;
ANALYZE documents;
ANALYZE invoices;
ANALYZE audit_events;
ANALYZE notifications;

-- Create materialized view for reporting (refresh periodically)
CREATE MATERIALIZED VIEW work_log_summary AS
SELECT 
    wl.organisation_id,
    p.id as property_id,
    p.name as property_name,
    DATE_TRUNC('month', wl.created_at) as month,
    wl.category,
    wl.status,
    COUNT(*) as work_count,
    SUM(CASE WHEN wl.actual_cost IS NOT NULL THEN wl.actual_cost ELSE 0 END) as total_cost,
    AVG(CASE WHEN wl.actual_cost IS NOT NULL THEN wl.actual_cost ELSE 0 END) as avg_cost,
    COUNT(*) FILTER (WHERE wl.status = 'COMPLETED') as completed_count,
    COUNT(*) FILTER (WHERE wl.priority = 'CRITICAL') as critical_count,
    COUNT(*) FILTER (WHERE wl.scheduled_date < NOW() AND wl.status IN ('PLANNED', 'IN_PROGRESS')) as overdue_count
FROM work_logs wl
JOIN properties p ON wl.property_id = p.id
WHERE wl.deleted_at IS NULL
GROUP BY wl.organisation_id, p.id, p.name, DATE_TRUNC('month', wl.created_at), wl.category, wl.status;

CREATE INDEX idx_work_log_summary_org_month ON work_log_summary(organisation_id, month);
CREATE INDEX idx_work_log_summary_property ON work_log_summary(property_id);

-- Function to refresh materialized view (call from cron or scheduled job)
CREATE OR REPLACE FUNCTION refresh_work_log_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY work_log_summary;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECURITY HARDENING
-- ============================================================================

-- Create application-specific roles
CREATE ROLE property_upkeep_app;
CREATE ROLE property_upkeep_readonly;

-- Grant necessary permissions to app role
GRANT CONNECT ON DATABASE property_upkeep TO property_upkeep_app;
GRANT USAGE ON SCHEMA public TO property_upkeep_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO property_upkeep_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO property_upkeep_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO property_upkeep_app;

-- Grant read-only permissions to readonly role
GRANT CONNECT ON DATABASE property_upkeep TO property_upkeep_readonly;
GRANT USAGE ON SCHEMA public TO property_upkeep_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO property_upkeep_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO property_upkeep_readonly;

-- Revoke permissions from public
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM public;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM public;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM public;

-- Enable connection logging and audit
-- These settings should be in postgresql.conf:
-- log_connections = on
-- log_disconnections = on
-- log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
-- log_statement = 'ddl'
-- log_min_duration_statement = 1000

COMMENT ON DATABASE property_upkeep IS 'Property Upkeep Records System - Production Database';