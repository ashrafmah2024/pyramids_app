-- سكربت للتحقق من وجود الجداول
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'purchase_expenses',
    'expense_allocation_rules',
    'purchase_items_costing',
    'purchases'
)
ORDER BY table_name;
