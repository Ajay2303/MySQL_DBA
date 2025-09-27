# MySQL Table Defragmentation 

## Objective
This guide provides the **general steps** to defragment MySQL tables using `ALTER TABLE`, `OPTIMIZE TABLE`, and `ANALYZE TABLE`. These commands help **reclaim unused space** and **improve query performance**.

---

## Syntax


## 1. Rebuild Table (In-place)
```
ALTER TABLE <database_name>.<table_name>
ENGINE=InnoDB, 
ALGORITHM=INPLACE, 
LOCK=NONE;

-- Rebuilds the table to reclaim unused space (defragmentation).
-- Uses in-place operation (ALGORITHM=INPLACE) to avoid full table copy.
-- LOCK=NONE allows table to remain available during operation.
```

## 2. Optimize Table
```
OPTIMIZE TABLE <database_name>.<table_name>;

-- Reclaims unused disk space.
-- Performs internal rebuild for InnoDB tables.
```
## 3. Analyze Table
```
ANALYZE TABLE <database_name>.<table_name>;

-- Updates table and index statistics.
-- Helps the query optimizer make efficient decisions.
```
