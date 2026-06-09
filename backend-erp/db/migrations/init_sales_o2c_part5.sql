-- =========================================================================
-- TYPES (ENUMs) สำหรับควบคุมสถานะเอกสารการขาย
-- =========================================================================
CREATE TYPE sales_doc_status AS ENUM ('draft', 'pending_approval', 'approved', 'rejected', 'cancelled', 'closed');
CREATE TYPE delivery_status AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned');
CREATE TYPE invoice_status AS ENUM ('unpaid', 'partial', 'paid', 'overdue', 'cancelled');
CREATE TYPE payment_method AS ENUM ('cash', 'bank_transfer', 'credit_card', 'cheque');

-- =========================================================================
-- 1. ใบเสนอราคา (Sales Quotes)
-- =========================================================================
CREATE TABLE sales_quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    salesperson_id UUID REFERENCES users(id),
    
    document_no VARCHAR(50) NOT NULL,
    document_date DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE,
    
    subtotal NUMERIC(18,2) DEFAULT 0.00,
    discount_amount NUMERIC(18,2) DEFAULT 0.00,
    tax_amount NUMERIC(18,2) DEFAULT 0.00,
    grand_total NUMERIC(18,2) DEFAULT 0.00,
    
    billing_address TEXT,
    shipping_address TEXT,
    
    status sales_doc_status DEFAULT 'draft',
    notes TEXT,
    
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_quote_no_tenant UNIQUE (tenant_id, document_no)
);

CREATE TABLE sales_quote_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_id UUID NOT NULL REFERENCES sales_quotes(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    uom_id UUID REFERENCES uoms(id),
    
    line_no INT NOT NULL,
    qty NUMERIC(18,4) NOT NULL,
    unit_price NUMERIC(18,2) NOT NULL,
    discount_amount NUMERIC(18,2) DEFAULT 0.00,
    total_amount NUMERIC(18,2) NOT NULL
);

-- =========================================================================
-- 2. ใบสั่งขาย (Sales Orders)
-- =========================================================================
CREATE TABLE sales_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    quote_id UUID REFERENCES sales_quotes(id),          
    salesperson_id UUID REFERENCES users(id),
    
    document_no VARCHAR(50) NOT NULL,
    document_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_delivery_date DATE,
    
    currency_code CHAR(3) DEFAULT 'THB',
    exchange_rate NUMERIC(18,6) DEFAULT 1,
    credit_limit NUMERIC(18,2),                         -- Snapshot วงเงินเครดิตลูกค้า ณ วันที่สั่งซื้อ
    credit_used NUMERIC(18,2),                          -- Snapshot เครดิตที่ใช้ไปแล้ว
    
    subtotal NUMERIC(18,2) DEFAULT 0.00,
    discount_amount NUMERIC(18,2) DEFAULT 0.00,
    tax_amount NUMERIC(18,2) DEFAULT 0.00,
    grand_total NUMERIC(18,2) DEFAULT 0.00,
    
    billing_address TEXT,
    shipping_address TEXT,
    
    status sales_doc_status DEFAULT 'draft',
    delivery_status delivery_status DEFAULT 'pending',
    notes TEXT,
    
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_order_no_tenant UNIQUE (tenant_id, document_no)
);

CREATE TABLE sales_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    uom_id UUID REFERENCES uoms(id),
    
    line_no INT NOT NULL,
    qty NUMERIC(18,4) NOT NULL,
    unit_price NUMERIC(18,2) NOT NULL,
    discount_amount NUMERIC(18,2) DEFAULT 0.00,
    total_amount NUMERIC(18,2) NOT NULL,
    
    qty_delivered NUMERIC(18,4) DEFAULT 0.00,           
    qty_invoiced NUMERIC(18,4) DEFAULT 0.00             
);

-- =========================================================================
-- 3. ใบจัดส่งสินค้า (Sales Deliveries / Delivery Orders)
-- =========================================================================
CREATE TABLE sales_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    order_id UUID NOT NULL REFERENCES sales_orders(id), 
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    
    document_no VARCHAR(50) NOT NULL,
    document_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    status delivery_status DEFAULT 'pending',
    tracking_number VARCHAR(100),                       
    carrier_name VARCHAR(100),                          
    
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_delivery_no_tenant UNIQUE (tenant_id, document_no)
);

CREATE TABLE sales_delivery_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES sales_deliveries(id) ON DELETE CASCADE,
    order_item_id UUID NOT NULL REFERENCES sales_order_items(id), 
    product_id UUID NOT NULL REFERENCES products(id),
    
    warehouse_id UUID REFERENCES warehouses(id),
    lot_no VARCHAR(100),
    serial_no VARCHAR(100),
    
    line_no INT NOT NULL,
    qty_delivered NUMERIC(18,4) NOT NULL
);

-- =========================================================================
-- 4. ใบแจ้งหนี้และภาษี (Sales Invoices & Tax Codes)
-- =========================================================================
CREATE TABLE tax_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(255) NOT NULL,
    tax_rate NUMERIC(5,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uq_tax_code_tenant UNIQUE(tenant_id, code)
);

CREATE TABLE sales_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    order_id UUID REFERENCES sales_orders(id),          
    delivery_id UUID REFERENCES sales_deliveries(id),   
    
    salesperson_id UUID REFERENCES users(id),
    
    document_no VARCHAR(50) NOT NULL,
    document_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    
    subtotal NUMERIC(18,2) DEFAULT 0.00,
    discount_amount NUMERIC(18,2) DEFAULT 0.00,
    tax_amount NUMERIC(18,2) DEFAULT 0.00,
    grand_total NUMERIC(18,2) DEFAULT 0.00,
    amount_paid NUMERIC(18,2) DEFAULT 0.00,             
    amount_due NUMERIC(18,2) GENERATED ALWAYS AS (grand_total - amount_paid) STORED, 
    
    billing_address TEXT,
    shipping_address TEXT,
    
    status invoice_status DEFAULT 'unpaid',
    
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_invoice_no_tenant UNIQUE (tenant_id, document_no)
);

CREATE TABLE sales_invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES sales_invoices(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    uom_id UUID REFERENCES uoms(id),
    
    order_item_id UUID REFERENCES sales_order_items(id),  -- แก้ไข: เติมลูกน้ำที่บรรทัดนี้แล้ว
    
    line_no INT NOT NULL,
    qty NUMERIC(18,4) NOT NULL,
    unit_price NUMERIC(18,2) NOT NULL,
    total_amount NUMERIC(18,2) NOT NULL
);

-- =========================================================================
-- 5. สกุลเงินและการรับชำระเงิน (Currencies & Customer Receipts)
-- =========================================================================
CREATE TABLE currencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code CHAR(3) NOT NULL,
    name VARCHAR(100),
    symbol VARCHAR(10),
    decimal_places INTEGER DEFAULT 2,
    CONSTRAINT uq_currency_code_tenant UNIQUE(tenant_id, code)
);

CREATE TABLE exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    currency_code CHAR(3) NOT NULL,
    rate NUMERIC(18,6) NOT NULL,
    effective_date DATE NOT NULL,
    CONSTRAINT uq_exchange_rate_tenant UNIQUE(tenant_id, currency_code, effective_date)
);

CREATE TABLE customer_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id),
    
    receipt_no VARCHAR(50) NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    payment_method payment_method NOT NULL,
    reference_no VARCHAR(100),                          
    total_paid NUMERIC(18,2) NOT NULL,                  
    
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_receipt_no_tenant UNIQUE (tenant_id, receipt_no)
);

CREATE TABLE customer_payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES customer_payments(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES sales_invoices(id),
    
    amount_allocated NUMERIC(18,2) NOT NULL             
);

-- =========================================================================
-- 6. ส่วนต่อขยายตารางเดิม และ Indexes (Extensions & Indexing)
-- =========================================================================
ALTER TABLE customers ADD COLUMN credit_days INTEGER;   -- (ตัด credit_limit ออกเพราะมีอยู่แล้วใน Part 4)

CREATE INDEX idx_sales_orders_cust ON sales_orders(tenant_id, customer_id);
CREATE INDEX idx_sales_invoices_status ON sales_invoices(tenant_id, status) WHERE status IN ('unpaid', 'partial', 'overdue');
CREATE INDEX idx_sales_doc_date ON sales_orders(document_date DESC);
CREATE INDEX idx_invoice_due_date ON sales_invoices(due_date ASC);