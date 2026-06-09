-- =========================================================================
-- BRANCHES
-- =========================================================================
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    address TEXT,

    is_main_branch BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT uq_branch_code_per_tenant
        UNIQUE (tenant_id, code),

    CONSTRAINT uq_branch_tenant
        UNIQUE (id, tenant_id)
);

COMMENT ON TABLE branches IS
'ตารางเก็บข้อมูลสาขาของแต่ละองค์กร';

-- =========================================================================
-- DEPARTMENTS
-- =========================================================================
CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tenant_id UUID NOT NULL
        REFERENCES tenants(id) ON DELETE CASCADE,

    branch_id UUID NOT NULL,

    parent_department_id UUID
        REFERENCES departments(id)
        ON DELETE SET NULL,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT uq_dept_code_per_branch
        UNIQUE (branch_id, code),

    CONSTRAINT uq_department_tenant
        UNIQUE (id, tenant_id)
);

ALTER TABLE departments
ADD CONSTRAINT fk_department_branch_tenant
FOREIGN KEY (
    branch_id,
    tenant_id
)
REFERENCES branches (
    id,
    tenant_id
)
ON DELETE CASCADE;

COMMENT ON TABLE departments IS
'ตารางเก็บข้อมูลแผนก';

-- =========================================================================
-- POSITIONS
-- =========================================================================
CREATE TABLE positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tenant_id UUID NOT NULL
        REFERENCES tenants(id)
        ON DELETE CASCADE,

    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,

    job_grade VARCHAR(50),

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT uq_pos_code_per_tenant
        UNIQUE (tenant_id, code),

    CONSTRAINT uq_position_tenant
        UNIQUE (id, tenant_id)
);

COMMENT ON TABLE positions IS
'ตารางเก็บตำแหน่งงาน';

-- =========================================================================
-- AUDIT LOGS (แก้ไข Primary Key รองรับ Partition)
-- =========================================================================
CREATE TABLE audit_logs (
    id UUID DEFAULT gen_random_uuid(), -- เอา PRIMARY KEY ออกจากตรงนี้
    
    tenant_id UUID NOT NULL 
        REFERENCES tenants(id) 
        ON DELETE CASCADE,
        
    user_id UUID 
        REFERENCES users(id) 
        ON DELETE SET NULL,
        
    action VARCHAR(50) NOT NULL 
        CHECK (
            action IN (
                'CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 
                'APPROVE', 'REJECT', 'EXPORT', 'IMPORT', 'PRINT', 'CANCEL'
            )
        ),
        
    entity_name VARCHAR(100) NOT NULL,
    entity_id UUID,
    
    old_values JSONB,
    new_values JSONB,
    
    ip_address VARCHAR(50),
    user_agent TEXT,
    request_id UUID,
    
    status VARCHAR(20) 
        CHECK (
            status IN ('SUCCESS', 'FAILED', 'DENIED')
        ),
        
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- ประกาศ Composite Primary Key เพื่อให้รองรับ Partition BY RANGE (created_at)
    PRIMARY KEY (id, created_at)
)
PARTITION BY RANGE (created_at);

COMMENT ON TABLE audit_logs IS 'ตารางเก็บ Audit Trail';

-- =========================================================================
-- EXAMPLE PARTITION
-- =========================================================================
CREATE TABLE audit_logs_2026_06 
PARTITION OF audit_logs 
FOR VALUES FROM ('2026-06-01') 
TO ('2026-07-01');

-- =========================================================================
-- USERS RELATIONSHIP
-- =========================================================================
ALTER TABLE users
ADD COLUMN branch_id UUID,
ADD COLUMN department_id UUID,
ADD COLUMN position_id UUID;

ALTER TABLE users
ADD CONSTRAINT fk_user_branch_tenant
FOREIGN KEY (
    branch_id,
    tenant_id
)
REFERENCES branches (
    id,
    tenant_id
);

ALTER TABLE users
ADD CONSTRAINT fk_user_department_tenant
FOREIGN KEY (
    department_id,
    tenant_id
)
REFERENCES departments (
    id,
    tenant_id
);

ALTER TABLE users
ADD CONSTRAINT fk_user_position_tenant
FOREIGN KEY (
    position_id,
    tenant_id
)
REFERENCES positions (
    id,
    tenant_id
);

-- =========================================================================
-- INDEXES
-- =========================================================================

CREATE UNIQUE INDEX uq_main_branch
ON branches (tenant_id)
WHERE is_main_branch = TRUE;

CREATE INDEX idx_branch_main
ON branches (
    tenant_id,
    is_main_branch
);

CREATE INDEX idx_branches_tenant
ON branches (tenant_id)
WHERE deleted_at IS NULL;

CREATE INDEX idx_departments_branch
ON departments (branch_id)
WHERE deleted_at IS NULL;

CREATE INDEX idx_department_parent
ON departments (parent_department_id);

CREATE INDEX idx_positions_tenant
ON positions (tenant_id)
WHERE deleted_at IS NULL;

CREATE INDEX idx_audit_logs_query
ON audit_logs (
    tenant_id,
    entity_name,
    entity_id
);

CREATE INDEX idx_audit_logs_timeline
ON audit_logs (
    created_at DESC
);