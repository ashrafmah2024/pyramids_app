-- سكربت لإضافة القيود الأجنبية بعد إنشاء جميع الجداول

-- 1. إضافة القيد الأجنبي من purchase_expenses إلى expense_allocation_rules
DO $$
BEGIN
    -- 1.1 إضافة القيد الأجنبي من purchase_expenses إلى expense_allocation_rules
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'purchase_expenses') AND 
       EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'expense_allocation_rules') THEN
        
        -- حذف القيد إذا كان موجوداً مسبقاً
        IF EXISTS (
            SELECT 1 
            FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_allocation_rule' 
            AND table_name = 'purchase_expenses'
        ) THEN
            ALTER TABLE purchase_expenses DROP CONSTRAINT fk_allocation_rule;
        END IF;
        
        -- إضافة القيد الجديد
        ALTER TABLE purchase_expenses
        ADD CONSTRAINT fk_allocation_rule 
        FOREIGN KEY (allocation_rule_id) 
        REFERENCES expense_allocation_rules(id) 
        ON DELETE SET NULL;
        
        RAISE NOTICE '1.1 تمت إضافة القيد الأجنبي fk_allocation_rule بنجاح';
    ELSE
        RAISE NOTICE '1.1 تحذير: لم يتم العثور على الجداول المطلوبة لإضافة القيد fk_allocation_rule';
    END IF;

    -- 1.2 إضافة القيد الأجنبي من purchase_expenses إلى purchases
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'purchase_expenses') AND 
       EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'purchases') THEN
        
        -- حذف القيد إذا كان موجوداً مسبقاً
        IF EXISTS (
            SELECT 1 
            FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_purchase_expenses_purchase' 
            AND table_name = 'purchase_expenses'
        ) THEN
            ALTER TABLE purchase_expenses DROP CONSTRAINT fk_purchase_expenses_purchase;
        END IF;
        
        -- إضافة القيد الجديد
        ALTER TABLE purchase_expenses
        ADD CONSTRAINT fk_purchase_expenses_purchase 
        FOREIGN KEY (purchase_id) 
        REFERENCES purchases(id) 
        ON DELETE CASCADE;
        
        RAISE NOTICE '1.2 تمت إضافة القيد الأجنبي fk_purchase_expenses_purchase بنجاح';
    ELSE
        RAISE NOTICE '1.2 تحذير: لم يتم العثور على جدول purchases لإضافة القيد الأجنبي';
    END IF;
END $$;

-- يمكنك إضافة المزيد من القيود هنا عند الحاجة

COMMENT ON TABLE purchase_expenses IS 'تم تحديث القيود الأجنبية بنجاح';
