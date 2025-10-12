# Overview of `pv` (Pipe Viewer)

`pv` (Pipe Viewer) is a command-line utility used to monitor the progress of data through a pipeline. It provides real-time feedback such as the amount of data transferred, transfer rate, elapsed time, percentage completed, and estimated time remaining.

## Common Use Cases of `pv`

### 1. Monitoring Database Backup and Restore Progress

**Create a MySQL dump:**
```
mysqldump -u user -p dbname | pv > backup.sql
```
Shows how much of the database dump has been written to the file.

**Restore a MySQL dump:**
```
pv backup.sql | mysql -u user -p dbname
```
Displays progress while restoring a large MySQL dump file.

### 2. Monitoring Large File Copies
```
pv largefile.iso > /mnt/backup/largefile.iso
```
Works like the cp command but provides a visual progress indicator for the file copy process.

### 3. Monitoring Compression and Decompression

**Compression:**
```
pv backup.sql | gzip > backup.sql.gz
```
Monitors the progress of file compression.

**Decompression:**
```
pv backup.sql.gz | gunzip > backup.sql
```
Displays the progress during file decompression.

### 4. Monitoring Data Transfer Over SSH
```
pv bigfile.tar | ssh user@remote 'cat > bigfile.tar'
```
Tracks the progress of a large file being transferred to a remote system via SSH.

### 5. Monitoring Disk Operations with dd

**Disk Cloning:**
```
pv /dev/sda > /dev/sdb
```
Shows progress while cloning drives or partitions.

**Disk Imaging:**
```
pv /dev/sda > disk_image.img
```
Displays progress while creating a disk image.

### 6. Monitoring Archive Creation
```
tar cf - /home/ajay | pv > backup.tar
```
Shows the progress of a tar archive being created.

### 7. Measuring System I/O Throughput
```
pv /dev/zero > /dev/null
```
Benchmarks and displays the system’s raw I/O throughput speed.

## Sample Output
```
2.34GB 0:00:45 [53.2MB/s] [===>                ]  25% ETA 0:02:15
```
## Explanation:

-- 2.34GB – Amount of data transferred so far

-- 0:00:45 – Elapsed time

-- 53.2MB/s – Current data transfer rate

-- 25% – Completion percentage

-- ETA 0:02:15 – Estimated time remaining
