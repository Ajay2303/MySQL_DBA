```
--1. Rebuild table and indexes, reclaim space
ALTER TABLE table_name ENGINE=InnoDB;
-- Rebuilds the table and its indexes from scratch.
-- Frees up disk space to the OS (for innodb_file_per_table=ON).
-- After this, the table is empty of unused space.

-- 2. Optimize table (optional if ALTER TABLE already done)
OPTIMIZE TABLE table_name;
-- Also rebuilds the table and reclaims space.
-- If ALTER TABLE already reclaimed space, this is mostly redundant, but safe to run.
-- Ensures the table is fully compacted.

-- 3. Analyze table statistics
ANALYZE TABLE table_name;
-- Updates the table statistics for the optimizer.
-- Should always be run after structural changes so MySQL has accurate stats for queries.
```
