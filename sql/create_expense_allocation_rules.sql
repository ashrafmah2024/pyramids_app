-- جدول قواعد توزيع المصروفات غير المباشرة
CREATE TABLE IF NOT EXISTS expense_allocation_rules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name_ar VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    description_ar TEXT,
    description_en TEXT,
    allocation_type VARCHAR(20) NOT NULL CHECK (allocation_type IN ('quantity', 'value', 'weight', 'custom')),
    is_active BOOLEAN DEFAULT true,
    created_by UUID, -- المستخدم الذي أنشأ القاعدة
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- القيم الافتراضية للتوزيع (تستخدم حسب نوع التوزيع)
    custom_ratio DECIMAL(5,2), -- نسبة مخصصة للتوزيع (0-100)
    
    -- القيم المحسوبة
    total_allocated_amount DECIMAL(15,2) DEFAULT 0.00,
    allocation_count INTEGER DEFAULT 0
);

-- فهارس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_expense_allocation_rules_type 
    ON expense_allocation_rules(allocation_type);

CREATE INDEX IF NOT EXISTS idx_expense_allocation_rules_active 
    ON expense_allocation_rules(is_active);

-- دالة تحديث التاريخ التلقائي
CREATE OR REPLACE FUNCTION update_expense_allocation_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- تطبيق الدالة على الجدول
DROP TRIGGER IF EXISTS trigger_expense_allocation_rules_updated_at ON expense_allocation_rules;
CREATE TRIGGER trigger_expense_allocation_rules_updated_at
    BEFORE UPDATE ON expense_allocation_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_expense_allocation_rules_updated_at();

-- تعليقات
COMMENT ON TABLE expense_allocation_rules IS 'جدول قواعد توزيع المصروفات غير المباشرة على المشتريات';
COMMENT ON COLUMN expense_allocation_rules.allocation_type IS 'نوع التوزيع: حسب الكمية، القيمة، الوزن، أو مخصص';
COMMENT ON COLUMN expense_allocation_rules.custom_ratio IS 'نسبة التوزيع المخصصة (0-100) إذا كان النوع مخصص';
COMMENT ON COLUMN expense_allocation_rules.total_allocated_amount IS 'إجمالي المبالغ الموزعة باستخدام هذه القاعدة';
COMMENT ON COLUMN expense_allocation_rules.allocation_count IS 'عدد مرات استخدام القاعدة في التوزيع';

-- إدخال قواعد افتراضية
INSERT INTO expense_allocation_rules 
    (id, name_ar, name_en, allocation_type, custom_ratio, is_active)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'حسب الكمية', 'By Quantity', 'quantity', NULL, true),
    ('22222222-2222-2222-2222-222222222222', 'حسب القيمة', 'By Value', 'value', NULL, true),
    ('33333333-3333-3333-3333-333333333333', 'حسب الوزن', 'By Weight', 'weight', NULL, true),
    ('44444444-4444-4444-4444-444444444444', 'نسبة مخصصة 50%', 'Custom 50%', 'custom', 50.00, true)
ON CONFLICT (id) DO NOTHING;
