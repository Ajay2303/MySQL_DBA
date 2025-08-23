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
