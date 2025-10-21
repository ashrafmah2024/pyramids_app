@echo off
echo "Recreating supplier_purchases table with full structure..."
cd /d "i:\Ashraf\Project\pyramids"

echo "Step 1: Drop existing table..."
psql -U postgres -d postgres -c "DROP TABLE IF EXISTS supplier_purchases CASCADE;"

echo "Step 2: Create new table with all columns and indexes..."
psql -U postgres -d postgres -f sql/recreate_supplier_purchases_table.sql

echo "Table recreation completed successfully!"
echo "You can now add purchases with supplier selection."
pause
