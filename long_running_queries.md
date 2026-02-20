-- LONG RUNNING QUERIES (10+ seconds)
-- These often hold locks even if not showing in lock waits
```
SELECT 
    p.id AS thread_id,
    p.user,
    p.host,
    p.db,
    p.command,
    p.time AS duration_seconds,
    p.state,
    LEFT(p.info, 150) AS query_text,
    COALESCE(trx.trx_rows_locked, 0) AS rows_locked,
    COALESCE(trx.trx_rows_modified, 0) AS rows_modified,
    CASE 
        WHEN p.time >= 120 THEN 'CRITICAL'
        WHEN p.time >= 60 THEN 'HIGH'
        WHEN p.time >= 30 THEN 'MEDIUM'
        WHEN p.time >= 10 THEN 'LOW'
    END AS priority,
    CONCAT('KILL ', p.id, ';') AS kill_command
FROM information_schema.PROCESSLIST p
LEFT JOIN information_schema.INNODB_TRX trx 
    ON trx.trx_mysql_thread_id = p.id
WHERE p.time >= 10
  AND p.command NOT IN ('Binlog Dump', 'Binlog Dump GTID', 'Sleep', 'Daemon')
  AND p.user != 'system user'
  AND (p.id != CONNECTION_ID() OR p.command != 'Query')
ORDER BY p.time DESC;
```
