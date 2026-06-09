-- =========================================================================
-- ส่วนที่ 6: ระบบจัดซื้อและรายจ่าย (Procure-to-Pay & Accounting Core)
-- (เวอร์ชันปิดการใช้งาน pgvector เพื่อแยกเซิร์ฟเวอร์ AI ในอนาคต)
-- =========================================================================

-- Types สำหรับฝั่งจัดซื้อ
CREATE TYPE approval_status AS ENUM ('draft', 'pending', 'approved', 'rejected');
CREATE TYPE purchase_doc_status AS ENUM ('draft', 'pending_approval', 'approved', 'rejected', 'cancelled', 'closed');

-- =========================================================================
-- 1. ใบขอซื้อ (Purchase Requisitions - PR)
-- =========================================================================
CREATE TABLE purchase_requisitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    document_no VARCHAR(50) NOT NULL,
    document_date DATE NOT NULL DEFAULT CURRENT_DATE,
    requested_by UUID REFERENCES users(id) ON DELETE SET NULL,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    status approval_status DEFAULT 'draft',
    remarks TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_pr_no_tenant UNIQUE (tenant_id, document_no)
);

CREATE TABLE purchase_requisition_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requisition_id UUID NOT NULL REFERENCES purchase_requisitions(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    qty NUMERIC(18,4) NOT NULL,
    estimated_price NUMERIC(18,2),
    required_date DATE
);

-- =========================================================================
-- 2. ขอใบเสนอราคาและเสนอราคาจากผู้ขาย (RFQ & Supplier Quotations)
-- =========================================================================
CREATE TABLE purchase_rfqs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    requisition_id UUID REFERENCES purchase_requisitions(id) ON DELETE SET NULL,
    document_no VARCHAR(50) NOT NULL,
    rfq_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status purchase_doc_status DEFAULT 'draft',
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_rfq_no_tenant UNIQUE (tenant_id, document_no)
);

CREATE TABLE supplier_quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    rfq_id UUID REFERENCES purchase_rfqs(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    quotation_no VARCHAR(100) NOT NULL,
    quotation_date DATE NOT NULL,
    total_amount NUMERIC(18,2),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

-- =========================================================================
-- 3. สัญญาและใบสั่งซื้อ (Contracts, Blanket PO & Purchase Orders)
-- =========================================================================
CREATE TABLE customer_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    contract_no VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    contract_value NUMERIC(18,2),
    status VARCHAR(30) DEFAULT 'active',
    terms_conditions TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_contract_no_tenant UNIQUE (tenant_id, contract_no)
);

CREATE TABLE blanket_purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    contract_start DATE,
    contract_end DATE,
    total_contract_amount NUMERIC(18,2),
    consumed_amount NUMERIC(18,2) DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    supplier_id UUID NOT NULL REFERENCES suppliers(id),
    quotation_id UUID REFERENCES supplier_quotations(id) ON DELETE SET NULL,
    
    document_no VARCHAR(50) NOT NULL,
    document_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery_date DATE,
    
    subtotal NUMERIC(18,2) DEFAULT 0,
    tax_amount NUMERIC(18,2) DEFAULT 0,
    grand_total NUMERIC(18,2) DEFAULT 0,
    currency_code CHAR(3) DEFAULT 'THB',
    exchange_rate NUMERIC(18,6) DEFAULT 1,
    status purchase_doc_status DEFAULT 'draft',
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_po_no_tenant UNIQUE (tenant_id, document_no)
);

CREATE TABLE purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    qty_ordered NUMERIC(18,4) NOT NULL,
    qty_received NUMERIC(18,4) DEFAULT 0,
    unit_cost NUMERIC(18,2) NOT NULL,
    total_amount NUMERIC(18,2) NOT NULL
);

-- =========================================================================
-- 4. การรับสินค้าและต้นทุนแฝง (Goods Receipts & Landed Costs)
-- =========================================================================
CREATE TABLE goods_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    purchase_order_id UUID REFERENCES purchase_orders(id) ON DELETE SET NULL,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    document_no VARCHAR(50) NOT NULL,
    receipt_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status delivery_status DEFAULT 'pending',
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_gr_no_tenant UNIQUE (tenant_id, document_no)
);

CREATE TABLE goods_receipt_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goods_receipt_id UUID NOT NULL REFERENCES goods_receipts(id) ON DELETE CASCADE,
    purchase_order_item_id UUID REFERENCES purchase_order_items(id) ON DELETE SET NULL,
    qty_received NUMERIC(18,4) NOT NULL,
    unit_cost NUMERIC(18,2) NOT NULL
);

CREATE TABLE landed_costs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    goods_receipt_id UUID NOT NULL REFERENCES goods_receipts(id) ON DELETE CASCADE,
    cost_type VARCHAR(50) NOT NULL, -- เช่น 'Freight', 'Customs', 'Insurance'
    amount NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================================
-- 5. ใบแจ้งหนี้และจ่ายเงิน (Supplier Invoices & Payments - AP)
-- =========================================================================
CREATE TABLE supplier_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id),
    purchase_order_id UUID REFERENCES purchase_orders(id) ON DELETE SET NULL,
    goods_receipt_id UUID REFERENCES goods_receipts(id) ON DELETE SET NULL,
    
    invoice_no VARCHAR(100) NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    
    subtotal NUMERIC(18,2) DEFAULT 0,
    tax_amount NUMERIC(18,2) DEFAULT 0,
    grand_total NUMERIC(18,2) DEFAULT 0,
    amount_paid NUMERIC(18,2) DEFAULT 0,
    amount_due NUMERIC(18,2) GENERATED ALWAYS AS (grand_total - amount_paid) STORED,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_sup_inv_no_tenant UNIQUE (tenant_id, supplier_id, invoice_no)
);

CREATE TABLE supplier_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id),
    payment_no VARCHAR(50) NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_method payment_method NOT NULL,
    total_paid NUMERIC(18,2) NOT NULL,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_sup_pay_no_tenant UNIQUE (tenant_id, payment_no)
);

CREATE TABLE supplier_payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES supplier_payments(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES supplier_invoices(id) ON DELETE CASCADE,
    amount_allocated NUMERIC(18,2) NOT NULL
);

CREATE TABLE supplier_scorecards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    on_time_delivery_score NUMERIC(5,2) DEFAULT 0,
    quality_score NUMERIC(5,2) DEFAULT 0,
    price_score NUMERIC(5,2) DEFAULT 0,
    overall_score NUMERIC(5,2),
    evaluated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================================
-- 6. ระบบบัญชีพื้นฐานและงบประมาณ (Accounting, Budgets, Fixed Assets)
-- =========================================================================
CREATE TABLE cost_centers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_cost_center_tenant UNIQUE (tenant_id, code)
);

CREATE TABLE profit_centers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_profit_center_tenant UNIQUE (tenant_id, code)
);

CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    fiscal_year INTEGER NOT NULL,
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    budget_amount NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_budget_dept_year UNIQUE (tenant_id, department_id, fiscal_year)
);

CREATE TABLE budget_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    reference_type VARCHAR(50),
    reference_id UUID,
    amount NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fixed_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    asset_code VARCHAR(100) NOT NULL,
    asset_name VARCHAR(255) NOT NULL,
    acquisition_cost NUMERIC(18,2) NOT NULL,
    useful_life_months INTEGER NOT NULL,
    salvage_value NUMERIC(18,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_asset_code_tenant UNIQUE (tenant_id, asset_code)
);

CREATE TABLE depreciation_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES fixed_assets(id) ON DELETE CASCADE,
    depreciation_date DATE NOT NULL,
    amount NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================================
-- 7. ระบบแนบไฟล์และ AI History (ส่วน Vector Database ปิดไว้ก่อน)
-- =========================================================================
CREATE TABLE attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    entity_type VARCHAR(100) NOT NULL, 
    entity_id UUID NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(100),
    version_no INTEGER,
    uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    question TEXT NOT NULL,
    answer TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/*
-- [คอมเมนต์] ปิดส่วน AI Vector ไว้เพื่อนำไปทำเป็น Database หรือ Microservice แยกในอนาคต
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE document_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    document_type VARCHAR(100) NOT NULL,
    document_id UUID NOT NULL,
    embedding VECTOR(1536),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_doc_embeddings_vector ON document_embeddings USING hnsw (embedding vector_l2_ops);
*/

-- =========================================================================
-- 8. Indexes (Performance Tuning)
-- =========================================================================
CREATE INDEX idx_po_tenant ON purchase_orders(tenant_id, document_no) WHERE deleted_at IS NULL;
CREATE INDEX idx_gr_tenant ON goods_receipts(tenant_id, document_no) WHERE deleted_at IS NULL;
CREATE INDEX idx_sup_inv_tenant ON supplier_invoices(tenant_id, supplier_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_attachments_entity ON attachments(entity_type, entity_id);