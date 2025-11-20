```
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    DATA_LENGTH/1024/1024 AS data_size_mb,
    INDEX_LENGTH/1024/1024 AS index_size_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'oa_customer_tmp_hst';
```
