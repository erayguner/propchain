-- Property Upkeep Records - Test Data
-- Development Environment Sample Data

SET search_path TO propchain, public;

-- Insert system roles
INSERT INTO roles (id, name, display_name, description, permissions, is_system_role) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'super_admin', 'Super Administrator', 'Full system access', '["*"]', true),
('550e8400-e29b-41d4-a716-446655440001', 'org_admin', 'Organization Administrator', 'Full organization access', '["org.*"]', true),
('550e8400-e29b-41d4-a716-446655440002', 'property_manager', 'Property Manager', 'Manage properties and work logs', '["property.*", "work_log.*", "document.*"]', true),
('550e8400-e29b-41d4-a716-446655440003', 'contractor', 'Contractor', 'View and update assigned work', '["work_log.view", "work_log.update", "document.create"]', true),
('550e8400-e29b-41d4-a716-446655440004', 'tenant', 'Tenant', 'View property history', '["property.view", "work_log.view"]', true),
('550e8400-e29b-41d4-a716-446655440005', 'auditor', 'Auditor', 'Read-only access for compliance', '["*.view", "audit.*"]', true);

-- Insert test organizations
INSERT INTO organizations (id, name, slug, description, settings) VALUES
('660e8400-e29b-41d4-a716-446655440000', 'Acme Property Management', 'acme-property', 'Leading property management company in London', '{"theme": "blue", "timezone": "Europe/London", "currency": "GBP"}'),
('660e8400-e29b-41d4-a716-446655440001', 'Green Estates Ltd', 'green-estates', 'Sustainable property development and management', '{"theme": "green", "timezone": "Europe/London", "currency": "GBP"}'),
('660e8400-e29b-41d4-a716-446655440002', 'City Living Properties', 'city-living', 'Urban residential property specialists', '{"theme": "purple", "timezone": "Europe/London", "currency": "GBP"}');

-- Insert test users
INSERT INTO users (id, email, first_name, last_name, phone, preferences, email_verified_at) VALUES
-- Acme Property Management users
('770e8400-e29b-41d4-a716-446655440000', 'admin@acme-property.com', 'Sarah', 'Johnson', '+44 20 7123 4567', '{"notifications": {"email": true, "sms": false}}', CURRENT_TIMESTAMP),
('770e8400-e29b-41d4-a716-446655440001', 'manager@acme-property.com', 'James', 'Smith', '+44 20 7123 4568', '{"notifications": {"email": true, "sms": true}}', CURRENT_TIMESTAMP),
('770e8400-e29b-41d4-a716-446655440002', 'contractor1@example.com', 'Mike', 'Wilson', '+44 20 7123 4569', '{"notifications": {"email": true, "sms": true}}', CURRENT_TIMESTAMP),
-- Green Estates users  
('770e8400-e29b-41d4-a716-446655440003', 'admin@green-estates.com', 'Emma', 'Davis', '+44 20 7234 5678', '{"notifications": {"email": true, "sms": false}}', CURRENT_TIMESTAMP),
('770e8400-e29b-41d4-a716-446655440004', 'maintenance@green-estates.com', 'Tom', 'Brown', '+44 20 7234 5679', '{"notifications": {"email": true, "sms": true}}', CURRENT_TIMESTAMP),
-- City Living users
('770e8400-e29b-41d4-a716-446655440005', 'admin@city-living.com', 'Lisa', 'Taylor', '+44 20 7345 6789', '{"notifications": {"email": true, "sms": false}}', CURRENT_TIMESTAMP),
('770e8400-e29b-41d4-a716-446655440006', 'tenant@example.com', 'John', 'Miller', '+44 7891 234567', '{"notifications": {"email": true, "sms": false}}', CURRENT_TIMESTAMP),
-- Auditor
('770e8400-e29b-41d4-a716-446655440007', 'auditor@compliance.com', 'Rachel', 'Green', '+44 20 7456 7890', '{"notifications": {"email": true, "sms": false}}', CURRENT_TIMESTAMP);

-- Assign roles to users
INSERT INTO user_organization_roles (user_id, organization_id, role_id, granted_by) VALUES
-- Acme Property Management
('770e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440001', '770e8400-e29b-41d4-a716-446655440000'),
('770e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440002', '770e8400-e29b-41d4-a716-446655440000'),
('770e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440003', '770e8400-e29b-41d4-a716-446655440000'),
-- Green Estates
('770e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '770e8400-e29b-41d4-a716-446655440003'),
('770e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440002', '770e8400-e29b-41d4-a716-446655440003'),
-- City Living
('770e8400-e29b-41d4-a716-446655440005', '660e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', '770e8400-e29b-41d4-a716-446655440005'),
('770e8400-e29b-41d4-a716-446655440006', '660e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440004', '770e8400-e29b-41d4-a716-446655440005'),
-- Cross-org auditor access
('770e8400-e29b-41d4-a716-446655440007', '660e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440005', '770e8400-e29b-41d4-a716-446655440000'),
('770e8400-e29b-41d4-a716-446655440007', '660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440005', '770e8400-e29b-41d4-a716-446655440003'),
('770e8400-e29b-41d4-a716-446655440007', '660e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440005', '770e8400-e29b-41d4-a716-446655440005');

-- Insert test properties
INSERT INTO properties (id, organization_id, name, description, address_line1, address_line2, city, county, postcode, property_type, floor_area_sqm, year_built, number_of_units, metadata) VALUES
-- Acme Property Management properties
('880e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'Riverside Apartments', 'Modern apartment complex by the Thames', '123 Thames View', 'Riverside Quarter', 'London', 'Greater London', 'SE1 2AB', 'residential', 2500.00, 2018, 24, '{"parking_spaces": 30, "lift_count": 2, "energy_rating": "B"}'),
('880e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440000', 'Victorian Terrace Houses', 'Renovated period properties in Islington', '45-67 Georgian Street', NULL, 'London', 'Greater London', 'N1 3CD', 'residential', 1800.00, 1890, 12, '{"heritage_listed": true, "garden_space": true}'),
('880e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440000', 'Commerce Tower', 'Commercial office building', '789 Business Avenue', 'Canary Wharf', 'London', 'Greater London', 'E14 5GH', 'commercial', 5000.00, 2020, 1, '{"floors": 12, "parking_spaces": 150, "conference_rooms": 8}'),
-- Green Estates properties
('880e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440001', 'Eco Village', 'Sustainable housing development', '101 Green Lane', 'Eco Quarter', 'Brighton', 'East Sussex', 'BN1 4EF', 'residential', 3200.00, 2021, 18, '{"solar_panels": true, "energy_rating": "A", "rainwater_harvesting": true}'),
('880e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440001', 'Sustainable Office Park', 'Green commercial complex', '456 Innovation Drive', NULL, 'Brighton', 'East Sussex', 'BN2 7HJ', 'commercial', 4200.00, 2022, 1, '{"leed_certified": true, "electric_vehicle_charging": 24}'),
-- City Living properties
('880e8400-e29b-41d4-a716-446655440005', '660e8400-e29b-41d4-a716-446655440002', 'Metropolitan Heights', 'High-rise luxury apartments', '1000 City Center', 'Financial District', 'Manchester', 'Greater Manchester', 'M1 5KL', 'residential', 6800.00, 2019, 45, '{"concierge_service": true, "gym": true, "roof_terrace": true}');

-- Insert work categories
INSERT INTO work_categories (id, organization_id, name, description, color_hex, is_system_category, sort_order) VALUES
-- System categories (shared across organizations)
('990e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'HVAC Maintenance', 'Heating, ventilation, and air conditioning', '#FF6B6B', true, 1),
('990e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440000', 'Plumbing', 'Water systems and drainage', '#4ECDC4', true, 2),
('990e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440000', 'Electrical', 'Electrical systems and lighting', '#45B7D1', true, 3),
('990e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440000', 'Security Systems', 'Access control, CCTV, alarms', '#96CEB4', true, 4),
('990e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440000', 'Lift Maintenance', 'Elevator and escalator service', '#FFEAA7', true, 5),
('990e8400-e29b-41d4-a716-446655440005', '660e8400-e29b-41d4-a716-446655440000', 'Building Fabric', 'Structural repairs and maintenance', '#DDA0DD', true, 6),
('990e8400-e29b-41d4-a716-446655440006', '660e8400-e29b-41d4-a716-446655440000', 'Cleaning', 'Routine and deep cleaning services', '#98D8C8', true, 7),
('990e8400-e29b-41d4-a716-446655440007', '660e8400-e29b-41d4-a716-446655440000', 'Landscaping', 'Garden and outdoor maintenance', '#90EE90', true, 8);

-- Insert assets
INSERT INTO assets (id, property_id, name, asset_type, manufacturer, model, serial_number, installation_date, warranty_expiry, location_description, specifications, maintenance_schedule) VALUES
-- Riverside Apartments assets
('aa0e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440000', 'Main HVAC Unit', 'hvac', 'Carrier', 'WeatherExpert 50TCQ', 'WE50TCQ123456', '2018-06-15', '2023-06-15', 'Roof level plant room', '{"capacity_kw": 120, "refrigerant": "R410A", "efficiency_rating": "A"}', '{"monthly": ["filter_check"], "quarterly": ["full_inspection"], "annually": ["deep_clean", "refrigerant_check"]}'),
('aa0e8400-e29b-41d4-a716-446655440001', '880e8400-e29b-41d4-a716-446655440000', 'Passenger Lift A', 'lift', 'Otis', 'Gen2 Premier', 'GP2023789', '2018-05-20', '2028-05-20', 'Main lobby, serves floors 1-8', '{"max_load_kg": 1000, "speed_ms": 1.5, "floors_served": 8}', '{"monthly": ["safety_check"], "quarterly": ["full_service"], "annually": ["load_test", "emergency_systems"]}'),
('aa0e8400-e29b-41d4-a716-446655440002', '880e8400-e29b-41d4-a716-446655440000', 'Passenger Lift B', 'lift', 'Otis', 'Gen2 Premier', 'GP2023790', '2018-05-20', '2028-05-20', 'North stairwell, serves floors 1-8', '{"max_load_kg": 1000, "speed_ms": 1.5, "floors_served": 8}', '{"monthly": ["safety_check"], "quarterly": ["full_service"], "annually": ["load_test", "emergency_systems"]}'),
-- Victorian Terrace assets
('aa0e8400-e29b-41d4-a716-446655440003', '880e8400-e29b-41d4-a716-446655440001', 'Central Boiler', 'boiler', 'Worcester Bosch', 'Greenstar', 'WB-GS-456789', '2020-03-10', '2025-03-10', 'Basement plant room', '{"output_kw": 80, "efficiency": 92, "fuel_type": "gas"}', '{"annually": ["service", "safety_check"], "monthly": ["pressure_check"]}'),
-- Commerce Tower assets
('aa0e8400-e29b-41d4-a716-446655440004', '880e8400-e29b-41d4-a716-446655440002', 'Executive Lift', 'lift', 'KONE', 'MonoSpace', 'MS789123', '2020-01-15', '2030-01-15', 'Executive lobby, serves floors 1-12', '{"max_load_kg": 1600, "speed_ms": 2.5, "floors_served": 12}', '{"monthly": ["safety_check"], "quarterly": ["full_service"], "annually": ["load_test"]}'),
('aa0e8400-e29b-41d4-a716-446655440005', '880e8400-e29b-41d4-a716-446655440002', 'Main HVAC System', 'hvac', 'Daikin', 'VRV IV', 'VRV4-987654', '2020-02-01', '2025-02-01', 'Roof plant room', '{"capacity_kw": 200, "zones": 24, "efficiency_rating": "A++"}', '{"monthly": ["filter_replacement"], "quarterly": ["system_check"], "annually": ["deep_service"]}');

-- Insert work logs (completed work records)
INSERT INTO work_logs (id, organization_id, property_id, asset_id, category_id, title, description, work_type, priority, status, completed_by, completed_at, verified_by, verified_at, labour_hours, material_cost, labour_cost, contractor_name, contractor_contact, warranty_period_months, notes, created_by) VALUES
-- Recent maintenance work
('bb0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440000', 'aa0e8400-e29b-41d4-a716-446655440000', '990e8400-e29b-41d4-a716-446655440000', 'Quarterly HVAC Filter Replacement', 'Replaced all air filters in main HVAC unit as per maintenance schedule', 'maintenance', 'medium', 'completed', '770e8400-e29b-41d4-a716-446655440002', '2023-12-15 10:30:00+00', '770e8400-e29b-41d4-a716-446655440001', '2023-12-15 16:00:00+00', 2.5, 150.00, 125.00, 'AC Experts Ltd', 'service@acexperts.co.uk', 6, 'All filters replaced with high-efficiency HEPA filters. System running optimally.', '770e8400-e29b-41d4-a716-446655440001'),

('bb0e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440000', 'aa0e8400-e29b-41d4-a716-446655440001', '990e8400-e29b-41d4-a716-446655440004', 'Lift Emergency Phone Repair', 'Emergency communication system in Lift A was not functioning. Replaced handset and tested connection.', 'repair', 'high', 'completed', '770e8400-e29b-41d4-a716-446655440002', '2023-12-20 14:15:00+00', '770e8400-e29b-41d4-a716-446655440001', '2023-12-20 15:30:00+00', 1.5, 85.00, 75.00, 'Otis Service', 'emergency@otis.com', 12, 'Emergency phone now fully operational. System tested with monitoring center.', '770e8400-e29b-41d4-a716-446655440001'),

('bb0e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440001', 'aa0e8400-e29b-41d4-a716-446655440003', '990e8400-e29b-41d4-a716-446655440000', 'Annual Boiler Service', 'Comprehensive annual service including safety checks, efficiency testing, and component replacement', 'maintenance', 'high', 'completed', '770e8400-e29b-41d4-a716-446655440002', '2023-11-30 09:00:00+00', '770e8400-e29b-41d4-a716-446655440001', '2023-11-30 17:00:00+00', 6.0, 320.00, 300.00, 'Heat Solutions Ltd', 'bookings@heatsolutions.co.uk', 12, 'Boiler passed all safety tests. Replaced worn gaskets and cleaned heat exchanger. Efficiency at 91%.', '770e8400-e29b-41d4-a716-446655440001'),

-- Property improvement work
('bb0e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440002', NULL, '990e8400-e29b-41d4-a716-446655440003', 'Security System Upgrade', 'Upgraded CCTV system to 4K cameras and replaced access control system with biometric readers', 'improvement', 'medium', 'completed', '770e8400-e29b-41d4-a716-446655440002', '2023-10-15 08:00:00+00', '770e8400-e29b-41d4-a716-446655440001', '2023-10-20 12:00:00+00', 24.0, 8500.00, 1200.00, 'SecureTech Systems', 'projects@securetech.co.uk', 24, 'Full system upgrade completed. 32 new cameras installed, all access points upgraded to biometric. Staff training provided.', '770e8400-e29b-41d4-a716-446655440001'),

-- Green Estates work
('bb0e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440001', '880e8400-e29b-41d4-a716-446655440003', NULL, '990e8400-e29b-41d4-a716-446655440007', 'Solar Panel Cleaning', 'Quarterly cleaning of all solar panels to maintain efficiency', 'maintenance', 'medium', 'completed', '770e8400-e29b-41d4-a716-446655440004', '2023-12-10 11:00:00+00', '770e8400-e29b-41d4-a716-446655440003', '2023-12-10 16:00:00+00', 4.0, 0.00, 200.00, 'Green Energy Services', 'maintenance@greenenergy.co.uk', 3, 'All 120 solar panels cleaned and inspected. Output efficiency increased by 8% post-cleaning.', '770e8400-e29b-41d4-a716-446655440003'),

-- Emergency repair work
('bb0e8400-e29b-41d4-a716-446655440005', '660e8400-e29b-41d4-a716-446655440002', '880e8400-e29b-41d4-a716-446655440005', NULL, '990e8400-e29b-41d4-a716-446655440001', 'Emergency Pipe Burst Repair', 'Water pipe burst in apartment 15A causing flooding. Emergency repair and water damage restoration.', 'repair', 'urgent', 'completed', '770e8400-e29b-41d4-a716-446655440006', '2023-12-22 03:30:00+00', '770e8400-e29b-41d4-a716-446655440005', '2023-12-23 10:00:00+00', 8.0, 450.00, 400.00, '24/7 Plumbing Services', 'emergency@247plumbing.co.uk', 6, 'Pipe repaired and tested. Water damage restoration completed. Tenant relocated temporarily during repairs.', '770e8400-e29b-41d4-a716-446655440005');

-- Insert sample documents
INSERT INTO documents (id, work_log_id, organization_id, title, description, document_type, file_name, file_path, file_size, mime_type, file_hash, metadata, tags, uploaded_by) VALUES
('cc0e8400-e29b-41d4-a716-446655440000', 'bb0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'Before - Dirty HVAC Filters', 'Photo showing condition of filters before replacement', 'photo', 'hvac_filters_before_20231215.jpg', '/uploads/documents/hvac_filters_before_20231215.jpg', 2048000, 'image/jpeg', 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', '{"camera": "iPhone 14", "gps_coordinates": [51.5074, -0.1278]}', '{"hvac", "maintenance", "before"}', '770e8400-e29b-41d4-a716-446655440002'),

('cc0e8400-e29b-41d4-a716-446655440001', 'bb0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'After - New HVAC Filters', 'Photo showing newly installed filters', 'photo', 'hvac_filters_after_20231215.jpg', '/uploads/documents/hvac_filters_after_20231215.jpg', 1956000, 'image/jpeg', 'b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7', '{"camera": "iPhone 14", "gps_coordinates": [51.5074, -0.1278]}', '{"hvac", "maintenance", "after"}', '770e8400-e29b-41d4-a716-446655440002'),

('cc0e8400-e29b-41d4-a716-446655440002', 'bb0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'HVAC Maintenance Certificate', 'Official maintenance completion certificate', 'certificate', 'hvac_maintenance_cert_20231215.pdf', '/uploads/documents/hvac_maintenance_cert_20231215.pdf', 524288, 'application/pdf', 'c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8', '{"pages": 2, "signed": true}', '{"certificate", "hvac", "compliance"}', '770e8400-e29b-41d4-a716-446655440002'),

('cc0e8400-e29b-41d4-a716-446655440003', 'bb0e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440000', 'Security Upgrade Before', 'Photo of old camera system', 'photo', 'security_old_system_20231015.jpg', '/uploads/documents/security_old_system_20231015.jpg', 1734000, 'image/jpeg', 'd4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9', '{"camera": "Samsung S21", "location": "main_entrance"}', '{"security", "upgrade", "before"}', '770e8400-e29b-41d4-a716-446655440002'),

('cc0e8400-e29b-41d4-a716-446655440004', 'bb0e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440000', 'Security Upgrade After', 'Photo of new 4K camera installation', 'photo', 'security_new_system_20231020.jpg', '/uploads/documents/security_new_system_20231020.jpg', 2156000, 'image/jpeg', 'e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0', '{"camera": "Samsung S21", "location": "main_entrance"}', '{"security", "upgrade", "after"}', '770e8400-e29b-41d4-a716-446655440002');

-- Insert sample invoices
INSERT INTO invoices (id, work_log_id, organization_id, invoice_number, supplier_name, supplier_contact, invoice_date, due_date, subtotal, tax_amount, total_amount, status, approved_by, approved_at, notes, created_by) VALUES
('dd0e8400-e29b-41d4-a716-446655440000', 'bb0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'ACE-2023-1234', 'AC Experts Ltd', '{"email": "billing@acexperts.co.uk", "phone": "+44 20 8123 4567", "address": "45 Industrial Estate, London N12 8HG"}', '2023-12-15', '2023-01-14', 275.00, 55.00, 330.00, 'approved', '770e8400-e29b-41d4-a716-446655440001', '2023-12-16 09:30:00+00', 'HVAC filter replacement - quarterly maintenance', '770e8400-e29b-41d4-a716-446655440001'),

('dd0e8400-e29b-41d4-a716-446655440001', 'bb0e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440000', 'OTIS-2023-5678', 'Otis Service', '{"email": "invoices@otis.com", "phone": "+44 20 7456 7890", "address": "Otis House, 25 Canada Square, London E14 5LQ"}', '2023-12-20', '2024-01-19', 160.00, 32.00, 192.00, 'approved', '770e8400-e29b-41d4-a716-446655440001', '2023-12-21 14:15:00+00', 'Emergency lift repair - phone system replacement', '770e8400-e29b-41d4-a716-446655440001'),

('dd0e8400-e29b-41d4-a716-446655440002', 'bb0e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440000', 'ST-2023-9876', 'SecureTech Systems', '{"email": "accounts@securetech.co.uk", "phone": "+44 20 9876 5432", "address": "Technology Park, Reading RG2 6GP"}', '2023-10-20', '2023-11-19', 9700.00, 1940.00, 11640.00, 'paid', '770e8400-e29b-41d4-a716-446655440001', '2023-10-22 11:00:00+00', 'Complete security system upgrade - cameras and access control', '770e8400-e29b-41d4-a716-446655440001');

-- Insert sample audit events
INSERT INTO audit_events (organization_id, entity_type, entity_id, action, actor_id, changes, metadata, ip_address) VALUES
('660e8400-e29b-41d4-a716-446655440000', 'work_log', 'bb0e8400-e29b-41d4-a716-446655440000', 'create', '770e8400-e29b-41d4-a716-446655440001', '{"before": null, "after": {"title": "Quarterly HVAC Filter Replacement"}}', '{"user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}', '192.168.1.100'),

('660e8400-e29b-41d4-a716-446655440000', 'work_log', 'bb0e8400-e29b-41d4-a716-446655440000', 'update', '770e8400-e29b-41d4-a716-446655440001', '{"before": {"status": "pending"}, "after": {"status": "completed"}}', '{"user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)"}', '10.0.1.50'),

('660e8400-e29b-41d4-a716-446655440000', 'document', 'cc0e8400-e29b-41d4-a716-446655440000', 'create', '770e8400-e29b-41d4-a716-446655440002', '{"before": null, "after": {"file_name": "hvac_filters_before_20231215.jpg"}}', '{"upload_method": "mobile_app"}', '192.168.1.105'),

('660e8400-e29b-41d4-a716-446655440000', 'invoice', 'dd0e8400-e29b-41d4-a716-446655440000', 'approve', '770e8400-e29b-41d4-a716-446655440001', '{"before": {"status": "pending"}, "after": {"status": "approved"}}', '{"approval_method": "web_interface"}', '192.168.1.100');

-- Insert sample notifications
INSERT INTO notifications (organization_id, recipient_id, type, title, message, data, channels, status, sent_at) VALUES
('660e8400-e29b-41d4-a716-446655440000', '770e8400-e29b-41d4-a716-446655440001', 'work_completion', 'Work Completed: HVAC Filter Replacement', 'The quarterly HVAC filter replacement at Riverside Apartments has been completed by Mike Wilson.', '{"work_log_id": "bb0e8400-e29b-41d4-a716-446655440000", "property_name": "Riverside Apartments"}', '{"email"}', 'delivered', '2023-12-15 16:30:00+00'),

('660e8400-e29b-41d4-a716-446655440000', '770e8400-e29b-41d4-a716-446655440001', 'invoice_approval', 'Invoice Requires Approval', 'Invoice ACE-2023-1234 from AC Experts Ltd (£330.00) requires your approval.', '{"invoice_id": "dd0e8400-e29b-41d4-a716-446655440000", "amount": 330.00, "supplier": "AC Experts Ltd"}', '{"email"}', 'delivered', '2023-12-15 18:00:00+00'),

('660e8400-e29b-41d4-a716-446655440000', '770e8400-e29b-41d4-a716-446655440002', 'urgent_repair', 'Urgent Repair Required', 'Emergency phone system failure reported in Lift A at Riverside Apartments.', '{"work_log_id": "bb0e8400-e29b-41d4-a716-446655440001", "priority": "high", "asset_name": "Passenger Lift A"}', '{"email", "sms"}', 'delivered', '2023-12-20 09:15:00+00');

-- Insert sample API tokens
INSERT INTO api_tokens (id, organization_id, name, description, token_hash, permissions, expires_at, created_by) VALUES
('ee0e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'Mobile App Token', 'Token for mobile application access', 'sha256$c2FsdA==$7f8e9d0c1b2a3948567e8f9a0b1c2d3e', '["work_log.view", "work_log.create", "document.create", "property.view"]', '2024-12-31 23:59:59+00', '770e8400-e29b-41d4-a716-446655440001'),

('ee0e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440000', 'Contractor Portal', 'API access for contractor portal integration', 'sha256$c2FsdA==$8g9f0e1d2c3b4a59678f0g1b2c3d4e5f', '["work_log.view", "work_log.update", "document.create"]', '2024-06-30 23:59:59+00', '770e8400-e29b-41d4-a716-446655440001');

-- Create some useful views for reporting
CREATE VIEW monthly_work_summary AS
SELECT 
    DATE_TRUNC('month', completed_at) as month,
    organization_id,
    COUNT(*) as total_jobs,
    SUM(CASE WHEN work_type = 'maintenance' THEN 1 ELSE 0 END) as maintenance_jobs,
    SUM(CASE WHEN work_type = 'repair' THEN 1 ELSE 0 END) as repair_jobs,
    SUM(CASE WHEN work_type = 'improvement' THEN 1 ELSE 0 END) as improvement_jobs,
    SUM(total_cost) as total_cost,
    AVG(labour_hours) as avg_labour_hours
FROM work_logs 
WHERE deleted_at IS NULL
GROUP BY DATE_TRUNC('month', completed_at), organization_id
ORDER BY month DESC;

CREATE VIEW property_maintenance_costs AS
SELECT 
    p.id as property_id,
    p.name as property_name,
    p.address_line1,
    p.postcode,
    COUNT(wl.id) as total_jobs,
    SUM(wl.total_cost) as total_cost,
    AVG(wl.total_cost) as avg_cost_per_job,
    SUM(CASE WHEN wl.work_type = 'maintenance' THEN wl.total_cost ELSE 0 END) as maintenance_cost,
    SUM(CASE WHEN wl.work_type = 'repair' THEN wl.total_cost ELSE 0 END) as repair_cost,
    SUM(CASE WHEN wl.work_type = 'improvement' THEN wl.total_cost ELSE 0 END) as improvement_cost
FROM properties p
LEFT JOIN work_logs wl ON p.id = wl.property_id AND wl.deleted_at IS NULL
WHERE p.deleted_at IS NULL
GROUP BY p.id, p.name, p.address_line1, p.postcode;

-- Insert some additional test data for demonstration
-- Add more recent work logs to show activity
INSERT INTO work_logs (organization_id, property_id, title, description, work_type, priority, status, completed_by, completed_at, labour_hours, material_cost, labour_cost, contractor_name, notes, created_by) VALUES
-- This week's work
('660e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440000', 'Weekly Cleaning - Common Areas', 'Deep clean of lobby, corridors, and shared facilities', 'maintenance', 'low', 'completed', '770e8400-e29b-41d4-a716-446655440002', CURRENT_TIMESTAMP - INTERVAL '2 days', 4.0, 25.00, 120.00, 'CleanCorp Services', 'Routine weekly cleaning completed. All areas sanitized.', '770e8400-e29b-41d4-a716-446655440001'),

('660e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440001', 'Gutter Cleaning', 'Annual gutter cleaning and inspection', 'maintenance', 'medium', 'completed', '770e8400-e29b-41d4-a716-446655440002', CURRENT_TIMESTAMP - INTERVAL '1 day', 6.0, 0.00, 180.00, 'Heights & Gutters Ltd', 'All gutters cleared. Minor repairs needed to downpipe joints identified for future work.', '770e8400-e29b-41d4-a716-446655440001'),

-- Today's work
('660e8400-e29b-41d4-a716-446655440000', '880e8400-e29b-41d4-a716-446655440000', 'Fire Alarm Monthly Test', 'Monthly fire alarm system test and inspection', 'maintenance', 'high', 'completed', '770e8400-e29b-41d4-a716-446655440002', CURRENT_TIMESTAMP - INTERVAL '3 hours', 1.5, 0.00, 95.00, 'Fire Safety Solutions', 'Monthly test completed. All zones responding correctly. Battery backup tested OK.', '770e8400-e29b-41d4-a716-446655440001');

-- Grant appropriate permissions for development
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA propchain TO propchain;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA propchain TO propchain;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA propchain TO propchain;

-- Create a simple function to get organization stats
CREATE OR REPLACE FUNCTION get_organization_stats(org_id UUID)
RETURNS TABLE(
    total_properties INTEGER,
    total_assets INTEGER,
    total_work_logs INTEGER,
    total_cost DECIMAL,
    avg_monthly_cost DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM properties WHERE organization_id = org_id AND deleted_at IS NULL),
        (SELECT COUNT(*)::INTEGER FROM assets a JOIN properties p ON a.property_id = p.id WHERE p.organization_id = org_id AND a.deleted_at IS NULL AND p.deleted_at IS NULL),
        (SELECT COUNT(*)::INTEGER FROM work_logs WHERE organization_id = org_id AND deleted_at IS NULL),
        (SELECT COALESCE(SUM(total_cost), 0) FROM work_logs WHERE organization_id = org_id AND deleted_at IS NULL),
        (SELECT COALESCE(AVG(monthly_total), 0) FROM (
            SELECT SUM(total_cost) as monthly_total 
            FROM work_logs 
            WHERE organization_id = org_id AND deleted_at IS NULL 
            GROUP BY DATE_TRUNC('month', completed_at)
        ) monthly_costs);
END;
$$ LANGUAGE plpgsql;

-- Test the function with sample data
SELECT * FROM get_organization_stats('660e8400-e29b-41d4-a716-446655440000');

COMMIT;