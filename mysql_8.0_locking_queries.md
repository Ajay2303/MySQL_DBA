# MySQL 8.0+ Locking Detection Queries (Performance Schema)

<p align="left">Author: Ajay S</p>

---

## Overview

This document provides a set of professional, ready-to-run SQL queries to detect and investigate locking issues on **MySQL 8.0+** instances using the **Performance Schema** and **INFORMATION_SCHEMA**. The queries focus on identifying current lock waits, long-running transactions, metadata locks (DDL blocking), table lock summaries, and connection patterns that commonly contribute to contention.

**Intended use**: operational troubleshooting, on-call runbooks, and integration into monitoring playbooks.

**Compatibility**: tested for MySQL 8.0.40+ (uses `performance_schema` views for metadata lock and data lock waits). Some queries reference `information_schema.INNODB_TRX` and `information_schema.PROCESSLIST`, which are widely available in MySQL 8.x.

---

## Prerequisites & Privileges

* The querying account should have **PROCESS** and **SELECT** privileges on `performance_schema` and `information_schema` (or be a user with sufficiently elevated privileges such as a DBA).
* Ensure `performance_schema` is enabled. Some views may require `performance_schema` consumers to be enabled for detailed lock information.
* Be careful when executing `KILL` statements returned by these queries — verify the impact before killing connections on production systems.

---

## Table of Contents

1. [Query 1 — Current Lock Waits](#query-1-current-lock-waits)
2. [Query 2 — High Row Lock Transactions](#query-2-high-row-lock-transactions)
3. [Query 3 — Long Running Queries (10+ seconds)](#query-3-long-running-queries-10-seconds)
4. [Query 4 — Metadata Lock Waits (DDL Blocking)](#query-4-metadata-lock-waits-ddl-blocking)
5. [Query 5 — Table Lock Summary](#query-5-table-lock-summary)
6. [Query 6 — Quick Health Check](#query-6-quick-health-check)
7. [Query 7 — Connection Count by Host](#query-7-connection-count-by-host)
8. [Query 8 — Specific Query Analysis](#query-8-specific-query-analysis)
9. [Query 9 — Find Specific Blocking Patterns](#query-9-find-specific-blocking-patterns)

---

## Query 1 — Current Lock Waits (MySQL 8.0+)

Shows which queries are blocking others **right now**.

```sql
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

**Notes**: Use this to get an immediate snapshot of blocking relationships. The `kill_command` column is a convenience — always confirm before running it.

---

## Query 2 — High Row Lock Transactions

Shows transactions holding many row locks (potential blockers).

```sql
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

**Notes**: Prioritize inspection of `CRITICAL` and `HIGH` severity transactions. Check the originating application and statement before killing threads.

---

## Query 3 — Long Running Queries (10+ seconds)

Long running queries frequently hold locks even if they don't appear in lock wait views.

```sql
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

**Notes**: Use this to identify queries that should be optimized or investigated for abnormal behavior.

---

## Query 4 — Metadata Lock Waits (DDL Blocking)

Shows queries waiting for table metadata locks (DDL blocking scenarios).

```sql
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

**Notes**: Metadata locks often surface during DDL operations (ALTER TABLE, DROP TABLE, etc.). Coordinate DDLs during low-traffic windows where possible.

---

## Query 5 — Table Lock Summary

Shows which tables have the most locks.

```sql
SELECT
    object_schema AS database_name,
    object_name AS table_name,
    COUNT(*) AS total_locks,
    COUNT(DISTINCT thread_id) AS unique_threads,
    SUM(CASE WHEN lock_type = 'TABLE' THEN 1 ELSE 0 END) AS table_locks,
    SUM(CASE WHEN lock_type = 'RECORD' THEN 1 ELSE 0 END) AS row_locks,
    GROUP_CONCAT(DISTINCT lock_mode ORDER BY lock_mode) AS lock_modes
FROM performance_schema.data_locks
GROUP BY object_schema, object_name
ORDER BY total_locks DESC
LIMIT 20;
```

**Notes**: Use this to find hot tables that may need schema, indexing or application-level changes.

---

## Query 6 — Quick Health Check

A fast overview of current locking state; suitable for dashboards or runbook checks.

```sql
SELECT
    'Total Active Transactions' AS metric,
    COUNT(*) AS value
FROM information_schema.INNODB_TRX

UNION ALL

SELECT
    'Transactions with 100+ Row Locks' AS metric,
    COUNT(*) AS value
FROM information_schema.INNODB_TRX
WHERE trx_rows_locked >= 100

UNION ALL

SELECT
    'Transactions with 1000+ Row Locks' AS metric,
    COUNT(*) AS value
FROM information_schema.INNODB_TRX
WHERE trx_rows_locked >= 1000

UNION ALL

SELECT
    'Queries Running 30+ Seconds' AS metric,
    COUNT(*) AS value
FROM information_schema.PROCESSLIST
WHERE time >= 30 AND command NOT IN ('Sleep', 'Daemon')

UNION ALL

SELECT
    'Queries Running 60+ Seconds' AS metric,
    COUNT(*) AS value
FROM information_schema.PROCESSLIST
WHERE time >= 60 AND command NOT IN ('Sleep', 'Daemon')

UNION ALL

SELECT
    'Active Data Lock Waits' AS metric,
    COUNT(*) AS value
FROM performance_schema.data_lock_waits

UNION ALL

SELECT
    'Metadata Lock Waits' AS metric,
    COUNT(*) AS value
FROM performance_schema.metadata_locks
WHERE lock_status = 'PENDING';
```

**Notes**: Return these metrics to a dashboard or alerting system for ongoing visibility.

---

## Query 7 — Connection Count by Host

Shows which hosts have the most connections.

```sql
SELECT
    SUBSTRING_INDEX(host, ':', 1) AS host_name,
    COUNT(*) AS connection_count,
    SUM(CASE WHEN command != 'Sleep' THEN 1 ELSE 0 END) AS active_connections,
    SUM(CASE WHEN time >= 30 THEN 1 ELSE 0 END) AS long_running_30s,
    AVG(time) AS avg_query_time_seconds
FROM information_schema.PROCESSLIST
WHERE user != 'system user'
GROUP BY host_name
ORDER BY connection_count DESC;
```

**Notes**: Identify noisy or runaway clients by host for throttling or connection pooling adjustments.

---

## Query 8 — Specific Query Analysis

Find similar queries — useful for identifying query patterns or duplicated inefficient statements.

```sql
SELECT
    LEFT(info, 100) AS query_pattern,
    COUNT(*) AS query_count,
    COUNT(DISTINCT id) AS unique_threads,
    AVG(time) AS avg_duration,
    MAX(time) AS max_duration,
    SUM(CASE WHEN time >= 30 THEN 1 ELSE 0 END) AS slow_count_30s,
    GROUP_CONCAT(DISTINCT SUBSTRING_INDEX(host, ':', 1) ORDER BY host) AS source_hosts
FROM information_schema.PROCESSLIST
WHERE command != 'Sleep'
  AND user != 'system user'
  AND info IS NOT NULL
GROUP BY LEFT(info, 100)
HAVING query_count > 1
ORDER BY query_count DESC, max_duration DESC
LIMIT 20;
```

**Notes**: Use these patterns to drive query fingerprinting and optimization efforts.

---

## Query 9 — Find Specific Blocking Patterns

Check for UPDATE/SELECT blocking patterns on specific application tables.

```sql
SELECT
    p.id AS thread_id,
    p.user,
    SUBSTRING_INDEX(p.host, ':', 1) AS host,
    p.time AS duration_seconds,
    p.state,
    trx.trx_rows_locked,
    trx.trx_tables_locked,
    LEFT(p.info, 200) AS query,
    CONCAT('KILL ', p.id, ';') AS kill_command
FROM information_schema.PROCESSLIST p
INNER JOIN information_schema.INNODB_TRX trx
    ON trx.trx_mysql_thread_id = p.id
WHERE (p.info LIKE '%ModelDetails%'
   OR p.info LIKE '%product_monitoring%'
   OR p.info LIKE '%impl_macserials%'
   OR p.info LIKE '%config_monitoring%')
  AND p.time >= 5
ORDER BY trx.trx_rows_locked DESC, p.time DESC;
```

**Notes**: Replace the table name patterns with application-specific identifiers relevant to your environment.

---

## Operational Guidance & Safety

* **Do not blindly execute `KILL` commands** returned by these queries. Confirm impact and coordinate with application owners when necessary.
* Running heavy `performance_schema` queries on very busy servers may add overhead — use during troubleshooting windows or execute from a monitoring replica when possible.
* For persistent problems, capture samples (`SHOW ENGINE INNODB STATUS`, `performance_schema` snapshots) and correlate with application traces.

---

## Integration & Automation

* Export these queries into a runbook (this file), or integrate into monitoring tooling (Grafana, Prometheus exporters, custom scripts) to surface metrics and alerts.
* Consider scheduling periodic snapshots (e.g., every 30s/1m) to a diagnostic table for historical analysis.

---

## Versioning & Changelog

* **Created:** 2026-02-20
* **MySQL tested against:** 8.0.40+

---

## License

MIT License — use freely in your operations and documentation.
