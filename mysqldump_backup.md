# **MySQL Table Backup using `mysqldump`**

This explains how to back up a specific table from a MySQL database using the `mysqldump` utility.

## **1. Basic Table Backup Command**
```
mysqldump -h hostname -u user -p dbname tablename > backupfilename_$(date +"%Y-%m-%d_%H-%M-%S").sql
```
## **Explanation**
```
| Option                                            | Description                                                      |
| :------------------------------------------------ | :--------------------------------------------------------------- |
| `-h hostname`                                     | Specifies the database host (e.g., `localhost` or RDS endpoint). |
| `-u user`                                         | MySQL username with privileges to access the database.           |
| `-p`                                              | Prompts for the password securely.                               |
| `dbname`                                          | The name of the database containing the table.                   |
| `tablename`                                       | The specific table to back up.                                   |
| `>`                                               | Redirects output to a file.                                      |
| `backupfilename_$(date +"%Y-%m-%d_%H-%M-%S").sql` | Creates a timestamped backup file.                               |
```

## **2. Advanced Table Backup Command**
```
mysqldump -h hostname \
  -u user -p \
  --single-transaction \
  --quick \
  --set-gtid-purged=OFF \
  --triggers \
  --routines \
  --events \
  dbname tablename > backupfilename_$(date +"%Y-%m-%d_%H-%M-%S").sql
```
## **Explanation**
```
| Option                  | Description                                                                                         |
| :---------------------- | :-------------------------------------------------------------------------------------------------- |
| `--single-transaction`  | Ensures a consistent snapshot by dumping data within a single transaction (recommended for InnoDB). |
| `--quick`               | Reads rows directly from the server without buffering (useful for large tables).                    |
| `--set-gtid-purged=OFF` | Excludes GTID info from the dump (recommended when restoring to non-GTID setups or RDS).            |
| `--triggers`            | Includes table triggers.                                                                            |
| `--routines`            | Includes stored procedures and functions.                                                           |
| `--events`              | Includes scheduled events.                                                                          |
```

## **3. Best Practices**

Use --single-transaction for InnoDB to avoid locking.

Disable GTIDs (--set-gtid-purged=OFF) for partial backups.

Use timestamped filenames for version tracking.

Store backups securely and set proper permissions.

Optionally compress backups:
```
gzip backupfilename_$(date +"%Y-%m-%d_%H-%M-%S").sql
```
