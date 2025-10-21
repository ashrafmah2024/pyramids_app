-- حذف وإعادة إنشاء جدول supplier_purchases
-- هذا الملف يحذف الجدول إذا كان موجود ويعيد إنشاؤه بالهيكل الصحيح

-- حذف الجدول مع جميع القيود والفهارس المرتبطة به
DROP TABLE IF EXISTS supplier_purchases CASCADE;

-- إنشاء الجدول بالهيكل الصحيح
CREATE TABLE supplier_purchases (
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

-- إنشاء الفهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_supplier_purchases_supplier_id ON supplier_purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_purchases_last_purchase_date ON supplier_purchases(last_purchase_date);
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

-- إدراج السجلات الأولية للموردين الموجودين (اختياري)
-- سيتم إنشاء السجلات تلقائياً عند إضافة المشتريات الأولى

COMMENT ON TABLE supplier_purchases IS 'جدول تتبع المشتريات من الموردين مع الإحصائيات';
COMMENT ON COLUMN supplier_purchases.supplier_id IS 'معرف المورد';
COMMENT ON COLUMN supplier_purchases.total_purchase_amount IS 'إجمالي المبلغ المشترى من هذا المورد';
COMMENT ON COLUMN supplier_purchases.purchase_count IS 'عدد المشتريات من هذا المورد';
COMMENT ON COLUMN supplier_purchases.average_purchase_amount IS 'متوسط قيمة المشتريات الواحدة';
COMMENT ON COLUMN supplier_purchases.last_purchase_date IS 'تاريخ آخر مشتريات من هذا المورد';
COMMENT ON COLUMN supplier_purchases.last_purchase_amount IS 'مبلغ آخر مشتريات';
COMMENT ON COLUMN supplier_purchases.last_purchase_reference IS 'رقم مرجع آخر مشتريات';
