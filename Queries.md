# MySQL DBA Queries

```sql
1. Check MySQL Version
SELECT VERSION();

2. Show Databases
SHOW DATABASES;

3. Show Tables in a Database
USE database_name;
SHOW TABLES;

4. Show Table Structure
DESCRIBE table_name;

5. Show Current Users
SELECT user, host FROM mysql.user;

6. Create a New User
CREATE USER 'username'@'localhost' IDENTIFIED BY 'password';

7. Grant Privileges
GRANT ALL PRIVILEGES ON database_name.* TO 'username'@'localhost';
FLUSH PRIVILEGES;

8. Show User Privileges
SHOW GRANTS FOR 'username'@'localhost';

9. Processlist (Active Queries)
SHOW FULL PROCESSLIST;

10. Check Current Connections
SHOW STATUS WHERE variable_name = 'Threads_connected';

11. Database Size (MB)
SELECT table_schema AS 'Database',
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
GROUP BY table_schema;

12. Table Size (MB)
SELECT table_name AS 'Table',
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'your_database_name'
ORDER BY (data_length + index_length) DESC;

13. Indexes on a Table
SHOW INDEX FROM table_name;

14. Show InnoDB Lock Waits
SELECT * FROM performance_schema.data_lock_waits;

15. Show Slow Queries
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'long_query_time';

16. Kill a Query
KILL QUERY query_id;

17. Backup a Database (CLI)
mysqldump -u root -p database_name > database_name.sql

18. Restore a Database (CLI)
mysql -u root -p database_name < database_name.sql

19. Check Uptime
SHOW GLOBAL STATUS LIKE 'Uptime';

20. Check Current Database
SELECT DATABASE();

21. Show Engine Status
SHOW ENGINE INNODB STATUS\G

22. Show Running Transactions
SELECT * FROM information_schema.innodb_trx\G

23. Check Open Tables
SHOW OPEN TABLES WHERE In_use > 0;

24. Check Number of Connections by Host
SELECT host, COUNT(*) AS connections
FROM information_schema.processlist
GROUP BY host;

25. Show Top 10 Largest Tables in All Databases
SELECT table_schema AS db,
       table_name AS table_name,
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
ORDER BY size_mb DESC
LIMIT 10;

26. Check Buffer Pool Size
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

27. Check Query Cache Status
SHOW VARIABLES LIKE 'query_cache%';

28. Show Binary Log Files
SHOW BINARY LOGS;

29. Show Current Binary Log File & Position
SHOW MASTER STATUS;

30. Show Replication Status (Slave)
SHOW SLAVE STATUS\G

31. Show Replication Status (Replica in 8.0+)
SHOW REPLICA STATUS\G

32. Flush Logs
FLUSH LOGS;

33. Enable General Query Log
SET GLOBAL general_log = 'ON';

34. Disable General Query Log
SET GLOBAL general_log = 'OFF';

35. Show Global Variables
SHOW GLOBAL VARIABLES;

36. Show Global Status
SHOW GLOBAL STATUS;

37. Find Queries Running Longer Than 5 Seconds
SELECT * 
FROM information_schema.processlist 
WHERE command != 'Sleep' AND time > 5;

38. Kill All Sleeping Connections
SELECT CONCAT('KILL ', id, ';') 
FROM information_schema.processlist 
WHERE command = 'Sleep';

39. Show Tables Without Primary Key
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
AND table_type = 'BASE TABLE'
AND table_name NOT IN (
  SELECT table_name FROM information_schema.table_constraints
  WHERE constraint_type = 'PRIMARY KEY'
);

40. Show Tables Without Indexes
SELECT t.table_schema, t.table_name
FROM information_schema.tables t
LEFT JOIN information_schema.statistics s
  ON t.table_schema = s.table_schema
 AND t.table_name = s.table_name
WHERE t.table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
AND s.table_name IS NULL
AND t.table_type = 'BASE TABLE';

41. Check Current Connections by User
SELECT user, COUNT(*) AS connections
FROM information_schema.processlist
GROUP BY user;

42. Show Top 10 Queries by Execution Time (from Performance Schema)
SELECT DIGEST_TEXT, COUNT_STAR, AVG_TIMER_WAIT/1000000000000 AS avg_time_sec
FROM performance_schema.events_statements_summary_by_digest
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 10;

43. Show Variables Matching a Keyword
SHOW VARIABLES LIKE '%timeout%';

44. Show Character Set & Collation
SHOW VARIABLES LIKE 'character_set%';
SHOW VARIABLES LIKE 'collation%';

45. Change Root Password (MySQL 5.7+)
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';

46. Check Current Default Database Engine
SHOW VARIABLES LIKE 'default_storage_engine';

47. List All Storage Engines
SHOW ENGINES;

48. Check Max Connections
SHOW VARIABLES LIKE 'max_connections';

49. Check Active Temporary Tables
SHOW GLOBAL STATUS LIKE 'Created_tmp%';

50. Show Top 5 Databases by Size
SELECT table_schema AS db,
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
GROUP BY table_schema
ORDER BY size_mb DESC
LIMIT 5;

51. Show Top 5 Largest Indexes
SELECT table_schema, table_name, index_name,
       ROUND(SUM(index_length) / 1024 / 1024, 2) AS index_size_mb
FROM information_schema.tables
GROUP BY table_schema, table_name, index_name
ORDER BY index_size_mb DESC
LIMIT 5;

52. Show Current Autocommit Status
SHOW VARIABLES LIKE 'autocommit';

53. Enable Autocommit
SET autocommit = 1;

54. Disable Autocommit
SET autocommit = 0;

55. Show Currently Running Backups (Percona XtraBackup etc.)
SHOW PROCESSLIST;

56. Show Table Fragmentation
SHOW TABLE STATUS LIKE 'table_name';

57. Optimize a Table
OPTIMIZE TABLE table_name;

58. Analyze a Table
ANALYZE TABLE table_name;

59. Check MySQL Error Log File Location
SHOW VARIABLES LIKE 'log_error';

60. Check Slow Query Log File Location
SHOW VARIABLES LIKE 'slow_query_log_file';

61. Count Total Rows in a Database
SELECT SUM(table_rows) AS total_rows
FROM information_schema.tables
WHERE table_schema = 'your_database';

62. Find Tables With More Than 1 Million Rows
SELECT table_schema, table_name, table_rows
FROM information_schema.tables
WHERE table_rows > 1000000;

63. Find Columns With NULL Values in a Table
SELECT COUNT(*) - COUNT(column_name) AS null_count
FROM table_name;

64. Find All Tables With AUTO_INCREMENT Columns
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE extra LIKE '%auto_increment%';

65. Reset AUTO_INCREMENT Counter
ALTER TABLE table_name AUTO_INCREMENT = 1;

66. Show Current Time Zone
SHOW VARIABLES LIKE 'time_zone';

67. Set Global Time Zone
SET GLOBAL time_zone = '+05:30';

68. Show Deadlocks
SHOW ENGINE INNODB STATUS\G

69. Show Tables Locked for Writes
SHOW OPEN TABLES WHERE In_use > 0;

70. Find Longest Queries Running Right Now
SELECT * 
FROM information_schema.processlist
ORDER BY time DESC
LIMIT 5;

71. Show Top 10 Most Frequently Run Queries (Performance Schema)
SELECT DIGEST_TEXT, COUNT_STAR AS exec_count
FROM performance_schema.events_statements_summary_by_digest
ORDER BY exec_count DESC
LIMIT 10;

72. Check Temporary Disk Tables
SHOW GLOBAL STATUS LIKE 'Created_tmp_disk_tables';

73. Check Table Cache Usage
SHOW STATUS LIKE 'Opened_tables';

74. Check Query Cache Hit Rate
SHOW STATUS LIKE 'Qcache%';

75. Disable Query Cache
SET GLOBAL query_cache_size = 0;

76. Check Binary Log Expiration
SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';

77. Purge Binary Logs Older Than 7 Days
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);

78. Show Replication Delay
SHOW SLAVE STATUS\G


Look for Seconds_Behind_Master.

79. Stop Replication
STOP SLAVE;

80. Start Replication
START SLAVE;

81. Check Global Buffer Pool Usage
SHOW ENGINE INNODB STATUS\G

82. Check Max Allowed Packet
SHOW VARIABLES LIKE 'max_allowed_packet';

83. Increase Max Allowed Packet
SET GLOBAL max_allowed_packet = 16777216;

84. Check Temp Table Size
SHOW VARIABLES LIKE 'tmp_table_size';

85. Show Active Transactions
SELECT * FROM information_schema.innodb_trx\G

86. Kill a Stuck Transaction
KILL CONNECTION trx_mysql_thread_id;

87. Show All Events (Scheduled Jobs)
SHOW EVENTS;

88. Show Event Scheduler Status
SHOW VARIABLES LIKE 'event_scheduler';

89. Enable Event Scheduler
SET GLOBAL event_scheduler = ON;

90. Disable Event Scheduler
SET GLOBAL event_scheduler = OFF;

91. Find Duplicate Indexes
SELECT DISTINCT t.table_schema, t.table_name, s.index_name
FROM information_schema.tables t
JOIN information_schema.statistics s
  ON t.table_schema = s.table_schema
 AND t.table_name = s.table_name
GROUP BY t.table_schema, t.table_name, s.index_name
HAVING COUNT(*) > 1;

92. Show Foreign Keys in a Table
SELECT constraint_name, table_name, referenced_table_name
FROM information_schema.referential_constraints
WHERE constraint_schema = 'your_database';

93. Drop a Foreign Key
ALTER TABLE table_name DROP FOREIGN KEY fk_name;

94. Disable Foreign Key Checks
SET FOREIGN_KEY_CHECKS = 0;

95. Enable Foreign Key Checks
SET FOREIGN_KEY_CHECKS = 1;

96. Show Stored Procedures
SHOW PROCEDURE STATUS WHERE Db = 'your_database';

97. Show Functions
SHOW FUNCTION STATUS WHERE Db = 'your_database';

98. Show Triggers
SHOW TRIGGERS FROM your_database;

99. Export Schema Only (No Data)
mysqldump -u root -p --no-data database_name > schema_only.sql

100. Export Data Only (No Schema)
mysqldump -u root -p --no-create-info database_name > data_only.sql
