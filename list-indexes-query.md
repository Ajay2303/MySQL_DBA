## List Indexes on a Table in MySQL

The following query retrieves all indexes for a specific table along with their associated columns in order:

```sql
SELECT 
    INDEX_NAME, 
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = 'database_name'
  AND TABLE_NAME = 'table_name'
GROUP BY INDEX_NAME;
