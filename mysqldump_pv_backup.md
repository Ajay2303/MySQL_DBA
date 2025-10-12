# Monitor MySQL Backup & Restore Progress Using `pv`

`pv` (Pipe Viewer) allows you to see the progress, speed, elapsed time, and ETA when transferring data, such as MySQL dumps or restores.

## 1. Install `pv`

### **Debian/Ubuntu**
```
sudo apt update
sudo apt install pv
```
### **RHEL/CentOS**
```
sudo yum install pv
```
## 2. Backup with Progress
### Monitor mysqldump progress
```
mysqldump -h hostname -u user -p dbname tablename | pv > backup_$(date +"%Y-%m-%d_%H-%M-%S").sql
```
### Backup and compress with progress
```
mysqldump -h hostname -u user -p dbname tablename | pv | gzip > backup_$(date +"%Y-%m-%d_%H-%M-%S").sql.gz
```
## Restore with Progress
### Restore plain SQL with progress
```
pv backup.sql | mysql -h hostname -u user -p dbname
```
### Restore compressed backup with progress
```
pv backup.sql.gz | gunzip | mysql -h hostname -u user -p dbname
```
## 4. Useful pv Options
```
| Option    | Description                                |
| --------- | ------------------------------------------ |
| `-p`      | Show progress bar                          |
| `-t`      | Show elapsed time                          |
| `-e`      | Show ETA                                   |
| `-r`      | Show current transfer rate                 |
| `-b`      | Show total bytes transferred               |
| `-s SIZE` | Specify total size for accurate percentage |
```
### Best Practices:

-- Always monitor large backups/restores with pv.

-- Use compression (gzip) for storage efficiency.

-- Timestamp backup filenames for easy tracking
