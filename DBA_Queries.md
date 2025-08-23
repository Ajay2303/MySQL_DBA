## MySQL DBA Queries

A collection of frequently used MySQL DBA queries and commands for day-to-day administration, performance tuning, monitoring, and troubleshooting.

## 1. Check MySQL Version
```sql
SELECT VERSION();

-- Shows the installed MySQL version.
```

## 2. Show Databases
```sql
SHOW DATABASES;

-- Lists all databases.
```

## 3. Show Tables in a Database
```sql
USE database_name;
SHOW TABLES;

-- Lists all tables in the selected database.
```

## 4. Show Table Structure
```sql
DESCRIBE table_name;

-- Displays the structure of a table (columns, types, keys).
```

## 5. Show Current Users
```sql
SELECT user, host FROM mysql.user;

-- Lists all MySQL users and their host access.
```

## 6. Create a New User
```sql
CREATE USER 'username'@'localhost' IDENTIFIED BY 'password';

-- Creates a new user with a password.
```

## 7. Grant Privileges
```sql
GRANT ALL PRIVILEGES ON database_name.* TO 'username'@'localhost';
FLUSH PRIVILEGES;

-- Grants full access to a user on a database and refreshes privileges.
```

## 8. Show User Privileges
```sql
SHOW GRANTS FOR 'username'@'localhost';

-- Displays the privileges assigned to a user.
```

## 9. Processlist (Active Queries)
```sql
SHOW FULL PROCESSLIST;

-- Shows active queries and their states.
```

## 10. Check Current Connections
```sql
SHOW STATUS WHERE variable_name = 'Threads_connected';

-- Displays the number of currently open connections.
```

## 11. Database Size (MB)
```sql
SELECT table_schema AS 'Database',
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
GROUP BY table_schema;

-- Lists databases with their sizes in MB.
```

## 12. Table Size (MB)
```sql
SELECT table_name AS 'Table',
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'your_database_name'
ORDER BY (data_length + index_length) DESC;

-- Lists tables in a database sorted by size.
```

## 13. Indexes on a Table
```sql
SHOW INDEX FROM table_name;

-- Displays index information for a given table.
```

## 14. Show InnoDB Lock Waits
```sql
SELECT * FROM performance_schema.data_lock_waits;

-- Shows transactions waiting for locks.
```

## 15. Show Slow Queries
```sql
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'long_query_time';

-- Displays slow query log status and threshold.
```

## 16. Kill a Query
```sql
KILL QUERY query_id;

-- Terminates a running query.
```

## 17. Backup a Database (CLI)
```bash
mysqldump -u root -p database_name > database_name.sql

-- Takes a logical backup of a database.
```

## 18. Restore a Database (CLI)
```bash
mysql -u root -p database_name < database_name.sql

-- Restores a database from a dump file.
```

## 19. Check Uptime
```sql
SHOW GLOBAL STATUS LIKE 'Uptime';

-- Displays MySQL server uptime in seconds.
```

## 20. Check Current Database
```sql
SELECT DATABASE();

-- Shows the currently selected database.
```

## 21. Show Engine Status
```sql
SHOW ENGINE INNODB STATUS\G

-- Provides detailed InnoDB engine metrics.
```

## 22. Show Running Transactions
```sql
SELECT * FROM information_schema.innodb_trx\G

-- Lists currently active transactions.
```

## 23. Check Open Tables
```sql
SHOW OPEN TABLES WHERE In_use > 0;

-- Displays tables that are currently in use.
```

## 24. Check Number of Connections by Host
```sql
SELECT host, COUNT(*) AS connections
FROM information_schema.processlist
GROUP BY host;

-- Shows number of connections per host.
```

## 25. Show Top 10 Largest Tables in All Databases
```sql
SELECT table_schema AS db,
       table_name AS table_name,
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
ORDER BY size_mb DESC
LIMIT 10;

-- Lists the largest tables across all databases.
```

## 26. Check Buffer Pool Size
```sql
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
-- Shows current InnoDB buffer pool size.
```
## 27. Check Query Cache Status
```sql
SHOW VARIABLES LIKE 'query_cache%';
-- Displays query cache settings.
```
## 28. Show Binary Log Files
```sql
SHOW BINARY LOGS;
-- Lists all binary log files.
```
## 29. Show Current Binary Log File & Position
```sql
SHOW MASTER STATUS;
-- Displays current binary log file in use.
```
## 30. Show Replication Status (Slave)
```sql
SHOW SLAVE STATUS\G
-- Shows replication status on a slave.
```
## 31. Show Replication Status (Replica 8.0+)
```sql
SHOW REPLICA STATUS\G
-- Shows replication status in MySQL 8+.
```
## 32. Flush Logs
```sql
FLUSH LOGS;
-- Closes and reopens log files.
```
## 33. Enable General Query Log
```sql
SET GLOBAL general_log = 'ON';
-- Enables general query logging.
```
## 34. Disable General Query Log
```sql
SET GLOBAL general_log = 'OFF';
-- Disables general query logging.
```
## 35. Show Global Variables
```sql
SHOW GLOBAL VARIABLES;
-- Displays all global variables.
```
## 36. Show Global Status
```sql
SHOW GLOBAL STATUS;
-- Displays server status variables.
```
## 37. Find Long Running Queries
```sql
SELECT * 
FROM information_schema.processlist
WHERE command != 'Sleep' AND time > 5;
-- Finds queries running longer than 5 seconds.
```
## 38. Kill All Sleeping Connections
```sql
SELECT CONCAT('KILL ',id,';') 
FROM information_schema.processlist
WHERE command='Sleep';
-- Generates KILL statements for sleeping connections.
```
## 39. Show Tables Without Primary Key
```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
AND table_type='BASE TABLE'
AND table_name NOT IN (
  SELECT table_name FROM information_schema.table_constraints
  WHERE constraint_type='PRIMARY KEY'
);
-- Lists tables without a primary key.
```
## 40. Show Tables Without Indexes
```sql
SELECT t.table_schema, t.table_name
FROM information_schema.tables t
LEFT JOIN information_schema.statistics s
ON t.table_schema=s.table_schema AND t.table_name=s.table_name
WHERE t.table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
AND s.table_name IS NULL;
-- Lists tables without any indexes.
```
## 41. Check Connections by User
```sql
SELECT user, COUNT(*) 
FROM information_schema.processlist
GROUP BY user;
-- Shows active connections grouped by user.
```
## 42. Show Top 10 Queries by Execution Time
```sql
SELECT DIGEST_TEXT, COUNT_STAR, AVG_TIMER_WAIT/1e12 AS avg_sec
FROM performance_schema.events_statements_summary_by_digest
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 10;
-- Displays top 10 queries with longest avg execution time.
```
## 43. Show Variables Matching Keyword
```sql
SHOW VARIABLES LIKE '%timeout%';
-- Displays variables containing "timeout".
```
## 44. Show Charset & Collation
```sql
SHOW VARIABLES LIKE 'character_set%';
SHOW VARIABLES LIKE 'collation%';
-- Shows current character set and collation settings.
```
## 45. Change Root Password
```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_pass';
-- Changes root user password.
```
## 46. Show Default Storage Engine
```sql
SHOW VARIABLES LIKE 'default_storage_engine';
-- Displays default storage engine.
```
## 47. List Storage Engines
```sql
SHOW ENGINES;
-- Lists available storage engines.
```
## 48. Check Max Connections
```sql
SHOW VARIABLES LIKE 'max_connections';
-- Displays max allowed connections.
```
## 49. Check Active Temporary Tables
```sql
SHOW GLOBAL STATUS LIKE 'Created_tmp%';
-- Shows number of temporary tables created.
```
## 50. Top 5 Databases by Size
```sql
SELECT table_schema, ROUND(SUM(data_length+index_length)/1024/1024,2) size_mb
FROM information_schema.tables
GROUP BY table_schema
ORDER BY size_mb DESC
LIMIT 5;
-- Lists top 5 largest databases by size.
```
## 51. Show Top 5 Largest Indexes
```sql
SELECT table_schema, table_name, index_name,
       ROUND(SUM(index_length)/1024/1024,2) AS index_size_mb
FROM information_schema.tables
GROUP BY table_schema, table_name, index_name
ORDER BY index_size_mb DESC
LIMIT 5;
-- Lists top 5 indexes by size.
```
## 52. Show Current Autocommit Status
```sql
SHOW VARIABLES LIKE 'autocommit';
-- Shows if autocommit is enabled.
```
## 53. Enable Autocommit
```sql
SET autocommit = 1;
-- Turns on autocommit.
```
## 54. Disable Autocommit
```sql
SET autocommit = 0;
-- Turns off autocommit.
```
## 55. Show Currently Running Backups
```sql
SHOW PROCESSLIST;
-- Identifies active backup processes.
```
## 56. Show Table Fragmentation
```sql
SHOW TABLE STATUS LIKE 'table_name';
-- Checks table fragmentation.
```
## 57. Optimize a Table
```sql
OPTIMIZE TABLE table_name;
-- Reorganizes fragmented data.
```
## 58. Analyze a Table
```sql
ANALYZE TABLE table_name;
-- Updates table statistics for optimizer.
```
## 59. Check Error Log File Location
```sql
SHOW VARIABLES LIKE 'log_error';
-- Displays error log file path.
```
## 60. Check Slow Query Log File Location
```sql
SHOW VARIABLES LIKE 'slow_query_log_file';
-- Displays slow query log file path.
```
## 61. Count Total Rows in a Database
```sql
SELECT SUM(table_rows) AS total_rows
FROM information_schema.tables
WHERE table_schema='your_database';
-- Counts total rows in a database.
```
## 62. Find Tables With More Than 1M Rows
```sql
SELECT table_schema, table_name, table_rows
FROM information_schema.tables
WHERE table_rows > 1000000;
-- Lists tables with over 1 million rows.
```
## 63. Find NULL Values in a Column
```sql
SELECT COUNT(*)-COUNT(column_name) AS null_count
FROM table_name;
-- Counts NULL values in a column.
```
## 64. Find Tables With AUTO_INCREMENT
```sql
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE extra LIKE '%auto_increment%';
-- Finds tables with AUTO_INCREMENT columns.
```
## 65. Reset AUTO_INCREMENT Counter
```sql
ALTER TABLE table_name AUTO_INCREMENT=1;
-- Resets auto-increment counter.
```
## 66. Show Current Time Zone
```sql
SHOW VARIABLES LIKE 'time_zone';
-- Displays current time zone.
```
## 67. Set Global Time Zone
```sql
SET GLOBAL time_zone='+05:30';
-- Changes server time zone.
```
## 68. Show Deadlocks
```sql
SHOW ENGINE INNODB STATUS\G
-- Deadlock info is at the bottom of the output.
```
## 69. Show Tables Locked for Writes
```sql
SHOW OPEN TABLES WHERE In_use > 0;
-- Shows tables currently locked.
```
## 70. Find Longest Running Queries
```sql
SELECT * 
FROM information_schema.processlist
ORDER BY time DESC
LIMIT 5;
-- Shows top 5 longest running queries.
```
## 71. Top 10 Most Frequently Run Queries
```sql
SELECT DIGEST_TEXT, COUNT_STAR AS exec_count
FROM performance_schema.events_statements_summary_by_digest
ORDER BY exec_count DESC
LIMIT 10;
-- Lists top 10 most frequently executed queries.
```
## 72. Check Temporary Disk Tables
```sql
SHOW GLOBAL STATUS LIKE 'Created_tmp_disk_tables';
-- Shows how many on-disk temporary tables were created.
```
## 73. Check Table Cache Usage
```sql
SHOW STATUS LIKE 'Opened_tables';
-- Displays number of opened tables.
```
## 74. Check Query Cache Hit Rate
```sql
SHOW STATUS LIKE 'Qcache%';
-- Displays query cache hit rate.
```
## 75. Disable Query Cache
```sql
SET GLOBAL query_cache_size=0;
-- Disables query cache.
```
## 76. Check Binary Log Expiration
```sql
SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';
-- Displays binlog expiration time in seconds.
```
## 77. Purge Binary Logs Older Than 7 Days
```sql
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);
-- Deletes binary logs older than 7 days.
```
## 78. Show Replication Delay
```sql
SHOW SLAVE STATUS\G
-- Look for "Seconds_Behind_Master" for delay.
```
## 79. Stop Replication
```sql
STOP SLAVE;
-- Stops replication.
```
## 80. Start Replication
```sql
START SLAVE;
-- Starts replication.
```
## 81. Check Buffer Pool Usage
```sql
SHOW ENGINE INNODB STATUS\G
-- Displays buffer pool usage.
```
## 82. Check Max Allowed Packet
```sql
SHOW VARIABLES LIKE 'max_allowed_packet';
-- Shows max allowed packet size.
```
## 83. Increase Max Allowed Packet
```sql
SET GLOBAL max_allowed_packet=16777216;
-- Increases packet size limit.
```
## 84. Check Temp Table Size
```sql
SHOW VARIABLES LIKE 'tmp_table_size';
-- Displays temporary table size.
```
## 85. Show Active Transactions
```sql
SELECT * FROM information_schema.innodb_trx\G
-- Lists active transactions.
```
## 86. Kill a Stuck Transaction
```sql
KILL CONNECTION trx_mysql_thread_id;
-- Kills a stuck transaction by thread ID.
```
## 87. Show All Events (Scheduled Jobs)
```sql
SHOW EVENTS;
-- Lists scheduled events.
```
## 88. Show Event Scheduler Status
```sql
SHOW VARIABLES LIKE 'event_scheduler';
-- Displays if event scheduler is enabled.
```
## 89. Enable Event Scheduler
```sql
SET GLOBAL event_scheduler=ON;
-- Enables event scheduler.
```
## 90. Disable Event Scheduler
```sql
SET GLOBAL event_scheduler=OFF;
-- Disables event scheduler.
```
## 91. Find Duplicate Indexes
```sql
SELECT DISTINCT t.table_schema, t.table_name, s.index_name
FROM information_schema.tables t
JOIN information_schema.statistics s
ON t.table_schema=s.table_schema AND t.table_name=s.table_name
GROUP BY t.table_schema, t.table_name, s.index_name
HAVING COUNT(*) > 1;
-- Finds duplicate indexes.
```
## 92. Show Foreign Keys in a Table
```sql
SELECT constraint_name, table_name, referenced_table_name
FROM information_schema.referential_constraints
WHERE constraint_schema='your_database';
-- Lists foreign keys in a table.
```
## 93. Drop a Foreign Key
```sql
ALTER TABLE table_name DROP FOREIGN KEY fk_name;
-- Drops a foreign key.
```
## 94. Disable Foreign Key Checks
```sql
SET FOREIGN_KEY_CHECKS=0;
-- Temporarily disables FK checks.
```
## 95. Enable Foreign Key Checks
```sql
SET FOREIGN_KEY_CHECKS=1;
-- Re-enables FK checks.
```
## 96. Show Stored Procedures
```sql
SHOW PROCEDURE STATUS WHERE Db='your_database';
-- Lists stored procedures.
```
## 97. Show Functions
```sql
SHOW FUNCTION STATUS WHERE Db='your_database';
-- Lists functions.
```
## 98. Show Triggers
```sql
SHOW TRIGGERS FROM your_database;
-- Lists triggers.
```
## 99. Export Schema Only (No Data)
```sql
mysqldump -u root -p --no-data database_name > schema_only.sql
-- Exports only schema without data.
```
## 100. Export Data Only (No Schema)
```sql
mysqldump -u root -p --no-create-info database_name > data_only.sql
-- Exports only data without schema.
```