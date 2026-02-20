-- CURRENT LOCK WAITS (MySQL 8.0+)
-- Shows which queries are blocking others RIGHT NOW

```
SELECT 
    waiting_trx.thread_id AS waiting_thread,
    waiting_trx.processlist_id AS waiting_pid,
    waiting_trx.processlist_time AS wait_seconds,
    waiting_lock.lock_type AS waiting_lock_type,
    waiting_lock.lock_mode AS waiting_lock_mode,
    waiting_lock.object_schema AS schema_name,
    waiting_lock.object_name AS table_name,
    waiting_lock.index_name,
    blocking_trx.thread_id AS blocking_thread,
    blocking_trx.processlist_id AS blocking_pid,
    blocking_trx.processlist_time AS blocking_duration,
    blocking_lock.lock_type AS blocking_lock_type,
    blocking_lock.lock_mode AS blocking_lock_mode,
    LEFT(waiting_trx.processlist_info, 100) AS waiting_query,
    LEFT(blocking_trx.processlist_info, 100) AS blocking_query,
    CONCAT('KILL ', blocking_trx.processlist_id, ';') AS kill_command
FROM performance_schema.data_lock_waits dlw
INNER JOIN performance_schema.data_locks waiting_lock
    ON dlw.requesting_engine_lock_id = waiting_lock.engine_lock_id
INNER JOIN performance_schema.data_locks blocking_lock
    ON dlw.blocking_engine_lock_id = blocking_lock.engine_lock_id
INNER JOIN performance_schema.threads waiting_trx
    ON waiting_lock.thread_id = waiting_trx.thread_id
INNER JOIN performance_schema.threads blocking_trx
    ON blocking_lock.thread_id = blocking_trx.thread_id
ORDER BY waiting_trx.processlist_time DESC;
```
