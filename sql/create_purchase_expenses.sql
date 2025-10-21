-- جدول مصروفات المشتريات (مباشرة وغير مباشرة)
CREATE TABLE IF NOT EXISTS purchase_expenses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    purchase_id UUID, -- سيتم إضافة القيد الأجنبي لاحقاً
    expense_type VARCHAR(20) NOT NULL CHECK (expense_type IN ('direct', 'indirect')),
    name_ar VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EGP',
    allocation_rule_id UUID, -- يمكن ربطه بقاعدة توزيع محددة
    notes TEXT,
    created_by UUID, -- المستخدم الذي أضاف المصروف
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- سيتم إضافة القيد الأجنبي لاحقاً بعد إنشاء الجدول
    -- CONSTRAINT fk_allocation_rule 
    --     FOREIGN KEY (allocation_rule_id) 
    --     REFERENCES expense_allocation_rules(id) 
    --     ON DELETE SET NULL
);

-- فهارس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_purchase_expenses_purchase_id 
    ON purchase_expenses(purchase_id);

CREATE INDEX IF NOT EXISTS idx_purchase_expenses_expense_type 
    ON purchase_expenses(expense_type);

-- دالة تحديث التاريخ التلقائي
CREATE OR REPLACE FUNCTION update_purchase_expenses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- تطبيق الدالة على الجدول
DROP TRIGGER IF EXISTS trigger_purchase_expenses_updated_at ON purchase_expenses;
CREATE TRIGGER trigger_purchase_expenses_updated_at
    BEFORE UPDATE ON purchase_expenses
    FOR EACH ROW
    EXECUTE FUNCTION update_purchase_expenses_updated_at();

-- تعليقات
COMMENT ON TABLE purchase_expenses IS 'جدول مصروفات المشتريات (مباشرة وغير مباشرة)';
COMMENT ON COLUMN purchase_expenses.expense_type IS 'نوع المصروف: مباشر أو غير مباشر';
COMMENT ON COLUMN purchase_expenses.amount IS 'قيمة المصروف';
COMMENT ON COLUMN purchase_expenses.currency IS 'العملة (مثل: EGP, USD)';
COMMENT ON COLUMN purchase_expenses.allocation_rule_id IS 'معرّف قاعدة التوزيع المستخدمة (للمصروفات غير المباشرة)';
COMMENT ON COLUMN purchase_expenses.notes IS 'ملاحظات إضافية';
COMMENT ON COLUMN purchase_expenses.created_by IS 'معرف المستخدم الذي أضاف السجل';
