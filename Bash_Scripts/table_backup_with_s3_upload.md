# MySQL Table-wise Backup Script with S3 Upload

This script performs **table-wise backups** of all MySQL databases (excluding system schemas), compresses them, uploads to **Amazon S3**, and maintains **local retention for 7 days**.  

It also sends an **email summary** with logs after completion.  

---

## Features
- Dumps each **table individually** (`mysqldump`)  
- Compresses using **gzip**  
- Uploads each table backup to **Amazon S3**  
- Maintains **7-day local retention policy**  
- Generates **detailed logs** per run  
- Sends **success/failure email notification** with logs attached  

---

## Script

```bash
#!/bin/bash

# === USER CONFIGURATION ===
MYSQL_HOST=""
MYSQL_USER=""
MYSQL_PASSWORD=""
S3_BUCKET=""
LOCAL_BACKUP_DIR="/volume/mysql_table_backups"
EMAIL_TO=""

# === INTERNAL CONFIG ===
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TODAY_DIR="${LOCAL_BACKUP_DIR}/${TIMESTAMP}"
LOG_FILE="/home/backup_log/mysql_table_backup_log_$TIMESTAMP.log"

mkdir -p "$TODAY_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# === SYSTEM DATABASES TO SKIP ===
SKIP_DB=("information_schema" "mysql" "performance_schema" "sys")

echo "Backup started at: $(date)" | tee -a "$LOG_FILE"
ALL_SUCCESS=true

# === FETCH ALL DATABASES ===
DATABASES=$(mysql -N -B -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT schema_name FROM information_schema.schemata;")

for DB in $DATABASES; do
    if [[ " ${SKIP_DB[*]} " == *" $DB "* ]]; then
        echo "Skipping system database: $DB" | tee -a "$LOG_FILE"
        continue
    fi

    echo "Processing database: $DB" | tee -a "$LOG_FILE"

    # === FETCH TABLES ===
    TABLES=$(mysql -N -B -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -D "$DB" -e "SHOW TABLES;")

    for TABLE in $TABLES; do
        BACKUP_NAME="${DB}.${TABLE}.${TIMESTAMP}.sql.gz"
        LOCAL_FILE="${TODAY_DIR}/${BACKUP_NAME}"
        S3_FILE="${S3_BUCKET}/${TIMESTAMP}/${BACKUP_NAME}"

        echo "Backing up $DB.$TABLE -> $LOCAL_FILE" | tee -a "$LOG_FILE"

        mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$DB" "$TABLE" \
            --single-transaction --quick --lock-tables=false 2>>"$LOG_FILE" | gzip > "$LOCAL_FILE"

        if [ $? -eq 0 ]; then
            echo "Local backup SUCCESS for: $DB.$TABLE" | tee -a "$LOG_FILE"

            # Upload to S3
            aws s3 cp "$LOCAL_FILE" "$S3_FILE" >> "$LOG_FILE" 2>&1

            if [ $? -eq 0 ]; then
                echo "Upload SUCCESS to S3: $DB.$TABLE" | tee -a "$LOG_FILE"
            else
                echo "Upload FAILED to S3: $DB.$TABLE" | tee -a "$LOG_FILE"
                ALL_SUCCESS=false
            fi
        else
            echo "Backup FAILED for: $DB.$TABLE" | tee -a "$LOG_FILE"
            ALL_SUCCESS=false
        fi
    done
done

# === CLEAN UP LOCAL FILES OLDER THAN 7 DAYS ===
echo "Cleaning up local backups older than 7 days..." | tee -a "$LOG_FILE"
find "$LOCAL_BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \; >> "$LOG_FILE" 2>&1

# === EMAIL SUMMARY ===
if [ "$ALL_SUCCESS" = true ]; then
    SUBJECT="MySQL Table-wise Backup Successful - $TIMESTAMP"
    echo "All tables backed up successfully and uploaded to S3." | mailx -s "$SUBJECT" -a "$LOG_FILE" "$EMAIL_TO"
else
    SUBJECT="MySQL Table-wise Backup FAILED - $TIMESTAMP"
    echo "Some table backups failed. Please check the attached log." | mailx -s "$SUBJECT" -a "$LOG_FILE" "$EMAIL_TO"
fi
```