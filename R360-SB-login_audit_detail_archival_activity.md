# `R360-SB-login_audit_detail` Archival Activity

## 1. Take Backup

Take a backup of the `portal.login_audit_detail` table before starting the archival activity.

```bash
mysqldump -h 10.70.1.127 -P 3307 -u 'jawahar.db@rapyder.com' -p portal login_audit_detail > login_audit_detail_backup.sql
```

> **Note:** If the DAM server (`10.70.1.127`) is not working, replace the hostname with the **RDS Endpoint** and port to 3306.

---

## 2. Prechecks

### Check the total record count

```sql
SELECT COUNT(*)
FROM portal.login_audit_detail;
```

### Check the records eligible for archival

```sql
SELECT COUNT(*)
FROM portal.login_audit_detail
WHERE log_in_time <= '<cutoff date> 23:59:59';
```

---

## 3. Archival Activity

### Step 1: Create the Archive Table

```sql
CREATE TABLE archivedb.login_audit_detail_archive AS
SELECT *
FROM portal.login_audit_detail;
```

### Step 2: Export Data to the Archive Database

```sql
INSERT INTO archivedb.login_audit_detail_archive
SELECT *
FROM portal.login_audit_detail
WHERE log_in_time <= '<cutoff date> 23:59:59';
```

### Step 3: Verify the Archived Record Count

```sql
SELECT COUNT(*)
FROM archivedb.login_audit_detail_archive;
```

Compare the archived count with the source archival count:

```sql
SELECT COUNT(*)
FROM portal.login_audit_detail
WHERE log_in_time <= '<cutoff date> 23:59:59';
```

> **Proceed with the deletion only if both counts match.**

---

## 4. Delete Archived Records from the Source Table

Delete the archived records in batches of `10,000`:

```sql
DELETE FROM portal.login_audit_detail
WHERE log_in_time <= '<cutoff date> 23:59:59'
LIMIT 10000;
```

Repeat the above `DELETE` statement until the following query returns `0`:

```sql
SELECT COUNT(*)
FROM portal.login_audit_detail
WHERE log_in_time <= '<cutoff date> 23:59:59';
```

---

## 5. Take Backup of the Archived Table

Once the deletion is completed, take a backup of the archived table:

```bash
mysqldump -h 10.70.1.127 -P 3307 -u 'jawahar.db@rapyder.com' -p archivedb login_audit_detail_archive > login_audit_detail_archive_backup.sql
```

> **Note:** If the DAM server (`10.70.1.127`) is not working, replace the hostname with the **RDS Endpoint** and port to 3306.

---

## 6. Upload the Archive Backup to S3

Inform the **Rapyder team** to upload the following archive dump file to **S3**:

```text
login_audit_detail_archive_backup.sql
```

---

## 7. Drop the Archive Table

Once the dump has been successfully uploaded to S3 and verified, drop the archive table:

```sql
DROP TABLE archivedb.login_audit_detail_archive;
```
