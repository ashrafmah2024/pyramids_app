-- سكربت للتحقق من جداول المشتريات
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE 'purchase%'
ORDER BY table_name;
