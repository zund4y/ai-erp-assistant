-- =========================================================================
-- TYPES (ENUMs)
-- =========================================================================
CREATE TYPE customer_status AS ENUM ('active', 'inactive', 'blocked');
CREATE TYPE supplier_status AS ENUM ('active', 'inactive', 'blocked');
CREATE TYPE warehouse_type AS ENUM ('main', 'transit', 'return', 'damaged');
CREATE TYPE product_type AS ENUM ('stock', 'service', 'asset', 'digital');
CREATE TYPE product_status AS ENUM ('draft', 'active', 'inactive', 'discontinued');

-- =========================================================================
-- 1. ตารางลูกค้า (Customers)
-- =========================================================================
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    customer_type VARCHAR(20) NOT NULL CHECK (customer_type IN ('individual','company')),
    name VARCHAR(255) NOT NULL,
    tax_id VARCHAR(50),
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    contact_name VARCHAR(255),
    contact_position VARCHAR(255),
    credit_limit DECIMAL(15,2) DEFAULT 0.00,
    payment_terms VARCHAR(100),
    status customer_status DEFAULT 'active',   -- เพิ่ม ENUM ที่สร้างไว้
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT uq_customer_code_tenant UNIQUE (tenant_id, code)
);
COMMENT ON TABLE customers IS 'ตารางข้อมูลหลักของลูกค้า รองรับทั้ง B2B และ B2C';

-- =========================================================================
-- 2. ตารางผู้จัดจำหน่าย (Suppliers / Vendors)
-- =========================================================================
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    tax_id VARCHAR(50),
    contact_name VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    status supplier_status DEFAULT 'active',   -- เพิ่ม ENUM ที่สร้างไว้
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT uq_supplier_code_tenant UNIQUE (tenant_id, code)
);
COMMENT ON TABLE suppliers IS 'ตารางข้อมูลหลักของผู้จัดจำหน่าย (Vendors/Suppliers)';

-- =========================================================================
-- 3. ตารางคลังสินค้า (Warehouses)
-- =========================================================================
CREATE TABLE warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    warehouse_type warehouse_type DEFAULT 'main',
    manager_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT uq_warehouse_code_tenant UNIQUE (tenant_id, code)
);
COMMENT ON TABLE warehouses IS 'ตารางคลังสินค้า ผูกตามโครงสร้างสาขา';

-- =========================================================================
-- 4. ตารางหน่วยนับ, ยี่ห้อ และ หมวดหมู่สินค้า (UOMs, Brands, Categories)
-- =========================================================================
CREATE TABLE uoms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_uom_code UNIQUE(tenant_id, code)
);

CREATE TABLE product_brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_brand UNIQUE(tenant_id, name)
);

CREATE TABLE product_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    sort_order INT DEFAULT 0,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_category_code_tenant UNIQUE (tenant_id, code)
);
COMMENT ON TABLE product_categories IS 'ตารางหมวดหมู่สินค้า รองรับโครงสร้างแบบ Tree';

-- =========================================================================
-- 5. ตารางสินค้าและส่วนขยาย (Products, Suppliers, Images)
-- =========================================================================
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    category_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,
    brand_id UUID REFERENCES product_brands(id) ON DELETE SET NULL,
    uom_id UUID REFERENCES uoms(id) ON DELETE SET NULL,
    
    code VARCHAR(50) NOT NULL,
    barcode VARCHAR(100),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    product_type product_type DEFAULT 'stock',
    status product_status DEFAULT 'active',
    
    standard_cost NUMERIC(18,2) DEFAULT 0,
    selling_price NUMERIC(18,2) DEFAULT 0,
    vat_rate NUMERIC(5,2) DEFAULT 7.00,
    reorder_point NUMERIC(18,2) DEFAULT 0,
    safety_stock NUMERIC(18,2) DEFAULT 0,

    weight NUMERIC(12,2),
    width NUMERIC(12,2),
    height NUMERIC(12,2),
    length NUMERIC(12,2),

    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT uq_product_code_tenant UNIQUE (tenant_id, code)
);
COMMENT ON TABLE products IS 'ตารางข้อมูลหลักของสินค้า (Items/SKUs)';

CREATE TABLE product_suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    supplier_product_code VARCHAR(100),
    purchase_price NUMERIC(18,2),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_supplier UNIQUE(product_id, supplier_id)
);

CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================================
-- 6. ตารางระบบคลังสินค้า (Inventory Transactions & Balances)
-- =========================================================================
CREATE TABLE inventory_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    transaction_type VARCHAR(30) NOT NULL, -- เช่น 'GR', 'GI', 'TRANSFER', 'ADJUST'
    reference_type VARCHAR(50),            -- เช่น 'PURCHASE_ORDER', 'SALES_ORDER'
    reference_id UUID,
    
    qty NUMERIC(18,4) NOT NULL,
    unit_cost NUMERIC(18,4),
    total_cost NUMERIC(18,4),
    transaction_date TIMESTAMPTZ NOT NULL,
    
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inventory_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    qty_on_hand NUMERIC(18,4) DEFAULT 0,
    qty_reserved NUMERIC(18,4) DEFAULT 0,
    qty_available NUMERIC(18,4) DEFAULT 0,  -- ปกติ = qty_on_hand - qty_reserved
    
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_inventory_balance UNIQUE(warehouse_id, product_id)
);

-- =========================================================================
-- 7. Indexes สำหรับเพิ่มความเร็วในการค้นหา (AI Search & Query Tuning)
-- =========================================================================
CREATE INDEX idx_customers_tenant ON customers(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_suppliers_tenant ON suppliers(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_warehouses_branch ON warehouses(branch_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_category ON products(category_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_tenant ON products(tenant_id) WHERE deleted_at IS NULL;

-- ดัชนีสำหรับการสแกนหาบาร์โค้ดที่ต้องทำงานให้เร็วที่สุด (Partial Index)
CREATE UNIQUE INDEX uq_product_barcode_tenant ON products(tenant_id, barcode) 
WHERE barcode IS NOT NULL AND deleted_at IS NULL;

-- ดัชนีระบบ Inventory สำหรับการคำนวณและสรุปยอด
CREATE INDEX idx_inv_tx_warehouse_product ON inventory_transactions(warehouse_id, product_id);
CREATE INDEX idx_inv_tx_date ON inventory_transactions(transaction_date DESC);