-- Check if units table exists and has data
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE  table_schema = 'public'
   AND    table_name   = 'units'
);

-- Check the structure of the units table
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'units';

-- Check if there's any data in the units table
SELECT COUNT(*) as unit_count FROM units;
