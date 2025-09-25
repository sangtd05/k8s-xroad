-- X-Road Central Server Database Schema Initialization
-- This script creates the basic tables required for X-Road Central Server

-- Create basic configuration tables
CREATE TABLE IF NOT EXISTS conf (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT
);

-- Insert basic configuration
INSERT INTO conf (key, value) VALUES 
('instance-identifier', 'EE'),
('central-server-address', 'cs-service:8443'),
('database-schema-version', '1.0')
ON CONFLICT (key) DO NOTHING;

-- Create serverconf table for server configuration
CREATE TABLE IF NOT EXISTS serverconf (
    server_code VARCHAR(255) PRIMARY KEY,
    server_class VARCHAR(255),
    server_owner VARCHAR(255),
    server_dns_name VARCHAR(255),
    server_ip VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create member table for X-Road members
CREATE TABLE IF NOT EXISTS member (
    id VARCHAR(255) PRIMARY KEY,
    member_class VARCHAR(255) NOT NULL,
    member_code VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(member_class, member_code)
);

-- Create subsystem table
CREATE TABLE IF NOT EXISTS subsystem (
    id VARCHAR(255) PRIMARY KEY,
    member_id VARCHAR(255) REFERENCES member(id),
    subsystem_code VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(member_id, subsystem_code)
);

-- Create service table
CREATE TABLE IF NOT EXISTS service (
    id VARCHAR(255) PRIMARY KEY,
    subsystem_id VARCHAR(255) REFERENCES subsystem(id),
    service_code VARCHAR(255) NOT NULL,
    service_version VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(subsystem_id, service_code, service_version)
);

-- Create access_right table
CREATE TABLE IF NOT EXISTS access_right (
    id VARCHAR(255) PRIMARY KEY,
    subject_id VARCHAR(255) NOT NULL,
    object_id VARCHAR(255) NOT NULL,
    rights_given_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create security_category table
CREATE TABLE IF NOT EXISTS security_category (
    code VARCHAR(255) PRIMARY KEY,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default security categories
INSERT INTO security_category (code, description) VALUES 
('PUBLIC', 'Public information'),
('INTERNAL', 'Internal use only'),
('CONFIDENTIAL', 'Confidential information'),
('RESTRICTED', 'Restricted information')
ON CONFLICT (code) DO NOTHING;

-- Create global_group table
CREATE TABLE IF NOT EXISTS global_group (
    code VARCHAR(255) PRIMARY KEY,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create local_group table
CREATE TABLE IF NOT EXISTS local_group (
    id VARCHAR(255) PRIMARY KEY,
    group_code VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create ca_info table for certificate authorities
CREATE TABLE IF NOT EXISTS ca_info (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    certificate_data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create timestamping_service table
CREATE TABLE IF NOT EXISTS timestamping_service (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    url VARCHAR(255),
    certificate_data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create ocsp_info table
CREATE TABLE IF NOT EXISTS ocsp_info (
    id VARCHAR(255) PRIMARY KEY,
    ca_name VARCHAR(255) NOT NULL,
    url VARCHAR(255),
    certificate_data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_member_class_code ON member(member_class, member_code);
CREATE INDEX IF NOT EXISTS idx_subsystem_member ON subsystem(member_id);
CREATE INDEX IF NOT EXISTS idx_service_subsystem ON service(subsystem_id);
CREATE INDEX IF NOT EXISTS idx_access_right_subject ON access_right(subject_id);
CREATE INDEX IF NOT EXISTS idx_access_right_object ON access_right(object_id);

-- Create a function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at
CREATE TRIGGER update_member_updated_at BEFORE UPDATE ON member FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_subsystem_updated_at BEFORE UPDATE ON subsystem FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_service_updated_at BEFORE UPDATE ON service FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_access_right_updated_at BEFORE UPDATE ON access_right FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ca_info_updated_at BEFORE UPDATE ON ca_info FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_timestamping_service_updated_at BEFORE UPDATE ON timestamping_service FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ocsp_info_updated_at BEFORE UPDATE ON ocsp_info FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin;
