@echo off
echo "Creating supplier_purchases table..."
cd /d "i:\Ashraf\Project\pyramids"
psql -U postgres -d postgres -f sql/create_supplier_purchases_table.sql
echo "Table creation completed."
pause
