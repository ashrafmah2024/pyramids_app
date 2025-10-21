-- جدول تكاليف بنود المشتريات
CREATE TABLE IF NOT EXISTS purchase_items_costing (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    
    -- التكاليف المباشرة
    direct_cost_per_unit DECIMAL(15,2) DEFAULT 0.00,
    total_direct_cost DECIMAL(15,2) DEFAULT 0.00,
    
    -- التكاليف غير المباشرة
    indirect_cost_per_unit DECIMAL(15,2) DEFAULT 0.00,
    total_indirect_cost DECIMAL(15,2) DEFAULT 0.00,
    
    -- إجمالي التكاليف
    total_cost_per_unit DECIMAL(15,2) GENERATED ALWAYS AS 
        (direct_cost_per_unit + indirect_cost_per_unit) STORED,
    total_cost DECIMAL(15,2) GENERATED ALWAYS AS 
        (total_direct_cost + total_indirect_cost) STORED,
    
    -- معلومات التسعير
    markup_percentage DECIMAL(5,2) DEFAULT 0.00, -- هامش الربح كنسبة مئوية
    selling_price_per_unit DECIMAL(15,2) GENERATED ALWAYS AS 
        (ROUND((direct_cost_per_unit + indirect_cost_per_unit) * 
         (1 + COALESCE(markup_percentage, 0) / 100), 2)) STORED,
    
    -- تتبع التغييرات
    last_calculation_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- فريدة لكل عملية شراء
    CONSTRAINT uq_purchase_costing UNIQUE (purchase_id)
);

-- فهارس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_purchase_items_costing_purchase 
    ON purchase_items_costing(purchase_id);

-- دالة تحديث التاريخ التلقائي
CREATE OR REPLACE FUNCTION update_purchase_items_costing_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.last_calculation_date = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- تطبيق الدالة على الجدول
DROP TRIGGER IF EXISTS trigger_purchase_items_costing_updated_at ON purchase_items_costing;
CREATE TRIGGER trigger_purchase_items_costing_updated_at
    BEFORE UPDATE ON purchase_items_costing
    FOR EACH ROW
    EXECUTE FUNCTION update_purchase_items_costing_updated_at();

-- تعليقات
COMMENT ON TABLE purchase_items_costing IS 'جدول تكاليف بنود المشتريات وحسابات الربح';
COMMENT ON COLUMN purchase_items_costing.direct_cost_per_unit IS 'التكلفة المباشرة للوحدة';
COMMENT ON COLUMN purchase_items_costing.indirect_cost_per_unit IS 'التكلفة غير المباشرة للوحدة';
COMMENT ON COLUMN purchase_items_costing.total_cost_per_unit IS 'التكلفة الإجمالية للوحدة (مباشرة + غير مباشرة)';
COMMENT ON COLUMN purchase_items_costing.markup_percentage IS 'هامش الربح كنسبة مئوية';
COMMENT ON COLUMN purchase_items_costing.selling_price_per_unit IS 'سعر البيع المقترح للوحدة';

-- دالة لحساب التكاليف تلقائياً عند إدخال بند جديد
CREATE OR REPLACE FUNCTION calculate_purchase_item_costing()
RETURNS TRIGGER AS $$
BEGIN
    -- هنا سيتم إضافة المنطق لحساب التكاليف تلقائياً
    -- يمكن استدعاؤها من التطبيق بعد إدخال المصروفات
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ملاحظة: سيتم تفعيل هذه الدالة بعد إكمال الجداول المرتبطة
