# MySQL Table Size and Fragmentation Check

## Objective
This guide provides SQL queries to **check table size and fragmentation** in any MySQL database. These queries help identify tables with unused space that may require defragmentation.

---

## 1. Check Size and Fragmentation for Specific Tables

```
SELECT 
    table_name AS `Table Name`,
    CONCAT(ROUND((data_length + index_length) / 1024 / 1024 / 1024, 3), 'G') AS `Current Size`,
    CONCAT(ROUND(data_free / 1024 / 1024 / 1024, 2), 'GB') AS `Fragmentation Size`
FROM information_schema.tables
WHERE table_schema = '<database_name>'
  AND table_name IN ('<table_name_1>', '<table_name_2>');
  
--Replace <database_name> with the database name.
--Replace <table_name_1>, <table_name_2> with the table(s) to check.
--data_length + index_length gives total table size (data + indexes).
--data_free indicates unused space (fragmentation).
```
## 2. Check Top 10 Tables by Fragmentation in a Database
```
SELECT
    CONCAT(table_schema, '.', table_name) AS `Table`,
    CONCAT(ROUND((data_length + index_length) / (1024 * 1024 * 1024), 3), 'G') AS `Table Size`,
    CONCAT(ROUND((data_free / 1024 / 1024 / 1024), 2), 'GB') AS `Data Free`,
    CONCAT(
        '(',
        IF(
            data_free < (data_length + index_length),
            CONCAT(ROUND(data_free / (data_length + index_length) * 100, 2), '%'),
            '100%'
        ),
        ')'
    ) AS `Data Free Pct`
FROM information_schema.TABLES
WHERE table_schema = 'flow_api'
ORDER BY data_free DESC
LIMIT 10;

```
## Notes:
```
--Run these queries before and after defragmentation to verify reclaimed space.
--Regular monitoring of fragmentation helps maintain database performance.
```
