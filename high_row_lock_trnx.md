
-- HIGH ROW LOCK TRANSACTIONS
-- Shows transactions holding many row locks (potential blockers)
```
SELECT 
    trx.trx_id,
    trx.trx_mysql_thread_id AS thread_id,
    trx.trx_state,
    trx.trx_started,
    TIMESTAMPDIFF(SECOND, trx.trx_started, NOW()) AS duration_seconds,
    trx.trx_rows_locked AS rows_locked,
    trx.trx_rows_modified AS rows_modified,
    trx.trx_tables_locked AS tables_locked,
    trx.trx_lock_structs AS lock_structs,
    ps.user,
    ps.host,
    ps.db,
    ps.command,
    ps.time AS query_time,
    ps.state AS query_state,
    LEFT(trx.trx_query, 150) AS trx_query,
    CASE 
        WHEN trx.trx_rows_locked > 10000 THEN 'CRITICAL'
        WHEN trx.trx_rows_locked > 1000 THEN 'HIGH'
        WHEN trx.trx_rows_locked > 100 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS lock_severity,
    CONCAT('KILL ', trx.trx_mysql_thread_id, ';') AS kill_command
FROM information_schema.INNODB_TRX trx
LEFT JOIN information_schema.PROCESSLIST ps 
    ON ps.id = trx.trx_mysql_thread_id
WHERE trx.trx_rows_locked > 0
ORDER BY trx.trx_rows_locked DESC, duration_seconds DESC;
```
