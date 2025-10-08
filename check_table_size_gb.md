```
SELECT table_schema, table_name,
       ROUND((data_length + index_length) / 1024 / 1024 / 1024, 2) AS size_gb
FROM information_schema.tables
WHERE table_name = 'table_name';
```
