-- METADATA LOCK WAITS (DDL Blocking)
-- Shows queries waiting for table metadata locks
```
SELECT 
    waiting.owner_thread_id AS waiting_thread,
    waiting.object_schema AS schema_name,
    waiting.object_name AS table_name,
    waiting.lock_type AS waiting_lock_type,
    waiting.lock_status AS waiting_lock_status,
    blocking.owner_thread_id AS blocking_thread,
    blocking.lock_type AS blocking_lock_type,
    blocking.lock_status AS blocking_lock_status,
    wt.processlist_id AS waiting_pid,
    wt.processlist_time AS wait_seconds,
    LEFT(wt.processlist_info, 100) AS waiting_query,
    bt.processlist_id AS blocking_pid,
    bt.processlist_time AS blocking_duration,
    LEFT(bt.processlist_info, 100) AS blocking_query,
    CONCAT('KILL ', bt.processlist_id, ';') AS kill_blocking
FROM performance_schema.metadata_locks waiting
INNER JOIN performance_schema.metadata_locks blocking
    ON waiting.object_schema = blocking.object_schema
    AND waiting.object_name = blocking.object_name
    AND waiting.lock_status = 'PENDING'
    AND blocking.lock_status = 'GRANTED'
INNER JOIN performance_schema.threads wt 
    ON waiting.owner_thread_id = wt.thread_id
INNER JOIN performance_schema.threads bt 
    ON blocking.owner_thread_id = bt.thread_id
WHERE waiting.object_type = 'TABLE'
ORDER BY wt.processlist_time DESC;
```
