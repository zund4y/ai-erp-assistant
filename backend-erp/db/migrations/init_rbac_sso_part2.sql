-- =========================================================================
-- 1. ตารางสิทธิ์การใช้งานพื้นฐานของระบบ (Permissions)
-- =========================================================================
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) UNIQUE NOT NULL,       -- เช่น 'user.create', 'invoice.approve'
    name VARCHAR(255) NOT NULL,
    description TEXT,
    module VARCHAR(100),                     -- จัดกลุ่มสิทธิ์ เช่น 'Accounting', 'Inventory'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE permissions IS 'ตารางเก็บ Master Data ของสิทธิ์การใช้งานทั้งหมดในระบบ';

-- =========================================================================
-- 2. ตารางบทบาทผู้ใช้งาน (Roles)
-- =========================================================================
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system BOOLEAN DEFAULT FALSE,         -- ป้องกันการลบ Role หลักของระบบ
    parent_role_id UUID REFERENCES roles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,     -- รองรับ Soft Delete
    CONSTRAINT uq_role_name_per_tenant UNIQUE (tenant_id, name)
);
COMMENT ON TABLE roles IS 'ตารางเก็บกลุ่มบทบาทผู้ใช้งาน แยกตามแต่ละองค์กร (Tenant)';

-- =========================================================================
-- 3. ตารางจับคู่บทบาทและสิทธิ์ (Role Permissions) พร้อม Scope
-- =========================================================================
CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    scope_code VARCHAR(100),
    permission_scope VARCHAR(50) DEFAULT 'all' CHECK (permission_scope IN ('own', 'branch', 'department', 'all')),
    PRIMARY KEY (role_id, permission_id)
);
COMMENT ON TABLE role_permissions IS 'ตารางเชื่อมบทบาทเข้ากับสิทธิ์ พร้อมกำหนดขอบเขตข้อมูล (Scope)';

-- =========================================================================
-- 4. ตารางกำหนดบทบาทให้ผู้ใช้งาน (User Roles)
-- =========================================================================
CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);
COMMENT ON TABLE user_roles IS 'ตารางกำหนดว่าผู้ใช้งานคนไหน ได้รับบทบาทอะไรบ้าง';

-- =========================================================================
-- 5. ตารางสิทธิ์พิเศษรายบุคคลและริบสิทธิ์ (User Direct Permissions)
-- =========================================================================
CREATE TABLE user_permissions (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    granted BOOLEAN DEFAULT TRUE,            -- TRUE = มอบสิทธิ์พิเศษ, FALSE = ริบสิทธิ์ (Override Role)
    scope_code VARCHAR(100),
    permission_scope VARCHAR(50) DEFAULT 'all' CHECK (permission_scope IN ('own', 'branch', 'department', 'all')),
    PRIMARY KEY (user_id, permission_id)
);
COMMENT ON TABLE user_permissions IS 'ตารางสำหรับให้สิทธิ์พิเศษข้าม Role หรือใช้ริบสิทธิ์เฉพาะบุคคล';

-- =========================================================================
-- 6. ตารางจัดการคีย์เชื่อมต่อ API (API Keys และ API Key Permissions)
-- =========================================================================
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    key_hash TEXT NOT NULL,                  -- เก็บเฉพาะค่า Hash ป้องกันคีย์จริงหลุด
    scopes TEXT[],                           -- Array เก็บรายการสิทธิ์เบื้องต้น
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL
);
COMMENT ON TABLE api_keys IS 'ตารางจัดการ API Key สำหรับลูกค้าหรือระบบภายนอก';

CREATE TABLE api_key_permissions (
    api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (api_key_id, permission_id)
);
COMMENT ON TABLE api_key_permissions IS 'ตารางกำหนดสิทธิ์แบบละเอียดให้แก่ API Key';

-- =========================================================================
-- 7. ตารางผู้ให้บริการยืนยันตัวตนองค์กร (SSO Providers)
-- =========================================================================
CREATE TABLE sso_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    provider_name VARCHAR(50) NOT NULL CHECK (provider_name IN ('azure_ad', 'google_workspace', 'okta', 'keycloak')),
    client_id VARCHAR(255) NOT NULL,
    client_secret_encrypted TEXT,
    metadata_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_tenant_provider UNIQUE (tenant_id, provider_name)
);
COMMENT ON TABLE sso_providers IS 'ตารางตั้งค่า Single Sign-On (SSO) สำหรับลูกค้าระดับ Enterprise';

-- =========================================================================
-- 8. บล็อกการสร้าง Indexes (Performance Tuning)
-- =========================================================================
CREATE INDEX idx_roles_tenant ON roles(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_api_keys_tenant ON api_keys(tenant_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_sso_providers_tenant ON sso_providers(tenant_id);