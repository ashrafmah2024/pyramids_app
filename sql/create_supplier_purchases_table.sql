-- جدول تتبع المشتريات من الموردين
-- يحتوي على إجماليات وحسابات لكل مورد

CREATE TABLE IF NOT EXISTS supplier_purchases (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,

    -- إحصائيات المشتريات
    total_purchase_amount DECIMAL(15,2) DEFAULT 0.00,
    purchase_count INTEGER DEFAULT 0,
    average_purchase_amount DECIMAL(15,2) DEFAULT 0.00,

    -- معلومات آخر مشتريات
    last_purchase_date TIMESTAMP WITH TIME ZONE,
    last_purchase_amount DECIMAL(15,2) DEFAULT 0.00,
    last_purchase_reference VARCHAR(50),

    -- حالة المورد
    is_active BOOLEAN DEFAULT true,

    -- تواريخ التتبع
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- فهرس للبحث السريع حسب المورد
CREATE INDEX IF NOT EXISTS idx_supplier_purchases_supplier_id ON supplier_purchases(supplier_id);

-- فهرس للبحث حسب التاريخ
CREATE INDEX IF NOT EXISTS idx_supplier_purchases_last_purchase_date ON supplier_purchases(last_purchase_date);

-- فهرس للبحث حسب النشاط
CREATE INDEX IF NOT EXISTS idx_supplier_purchases_active ON supplier_purchases(is_active);

-- دالة لتحديث وقت التحديث تلقائياً
CREATE OR REPLACE FUNCTION update_supplier_purchases_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- تطبيق الدالة على الجدول
DROP TRIGGER IF EXISTS trigger_supplier_purchases_updated_at ON supplier_purchases;
CREATE TRIGGER trigger_supplier_purchases_updated_at
    BEFORE UPDATE ON supplier_purchases
    FOR EACH ROW
    EXECUTE FUNCTION update_supplier_purchases_updated_at();

-- تعليق إضافة البيانات التجريبية (سيتم تنفيذها لاحقاً)
-- INSERT INTO supplier_purchases (supplier_id, total_purchase_amount, purchase_count)
-- SELECT
--     id,
--     0.00 as total_purchase_amount,
--     0 as purchase_count
-- FROM suppliers
-- WHERE id NOT IN (SELECT supplier_id FROM supplier_purchases WHERE supplier_id IS NOT NULL);
