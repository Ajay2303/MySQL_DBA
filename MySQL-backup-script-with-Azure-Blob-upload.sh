'''
#!/bin/bash
# --------------------------------------------------------------------
# MySQL Core DB Backup Script
# Daily Backup -> Azure Blob Storage
# --------------------------------------------------------------------

set -o pipefail

START_TIME=$(date +%s)
HOSTNAME=$(hostname)

# --------------------------------------------------------------------
# MySQL Credentials
# --------------------------------------------------------------------

USER=""
PASSWORD=''
HOST=""

CLIENT_NAME=""

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="core_db_backup_${DATE}.sql.gz"

# --------------------------------------------------------------------
# Local Backup Directory
# --------------------------------------------------------------------

MONTH=$(date +'%b_%Y')
BACKUP_DIR="/mnt/mysqldbbackup/Core_DB_backup/${MONTH}"

mkdir -p "$BACKUP_DIR"
LOG_DIR="/var/log/coredb_backup"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/coredb_backup.log"

# --------------------------------------------------------------------
# Azure Blob Storage
# --------------------------------------------------------------------

# Find azcopy location
if [ -f "/usr/local/bin/azcopy" ]; then
    AZCOPY="/usr/local/bin/azcopy"
elif [ -f "/usr/bin/azcopy" ]; then
    AZCOPY="/usr/bin/azcopy"
elif command -v azcopy &> /dev/null; then
    AZCOPY=$(command -v azcopy)
else
    AZCOPY="azcopy"
fi

echo "$(date): Using azcopy at: $AZCOPY" >> "$LOGFILE"

# Container URL with SAS token
CONTAINER_URL="https://cpmysqldbbackup.blob.core.windows.net/coredbbackups"
SAS_TOKEN="?sp=racwl&st=2026-08-03T06:07:39Z&se=2027-08-03T14:22:39Z&spr=https&sv=2026-02-06&sr=c&sig=kpmAOpeinFSyNT2fgCNGv7Ot3FClqnC7WGKb9WDiGVE%3D"

# Full container URL with SAS token
FULL_CONTAINER_URL="${CONTAINER_URL}${SAS_TOKEN}"

# Destination path within container
DEST_PATH="Core_DB/${MONTH}/${FILENAME}"

# --------------------------------------------------------------------
# Mail Settings
# --------------------------------------------------------------------

MAIL_FROM="Credopay Alerts <mysqlalert2@gmail.com>"
MAIL_TO=""
MAIL_SUBJECT=""

MYSQLDUMP="/usr/bin/mysqldump"
SENDMAIL="/usr/sbin/sendmail"

ERROR_LOG="/tmp/mysql_backup_error.log"
AZCOPY_LOG="/tmp/azcopy_error.log"
BACKUP_SIZE=""
UPLOAD_STATUS_MSG=""

# Status variables
BACKUP_STATUS="FAILED"
UPLOAD_STATUS="FAILED"
FINAL_STATUS="FAILED"

# --------------------------------------------------------------------
# Clean logs
# --------------------------------------------------------------------

> "$ERROR_LOG"
> "$AZCOPY_LOG"

# --------------------------------------------------------------------
# RUN BACKUP
# --------------------------------------------------------------------

echo "$(date): ==========================================" >> "$LOGFILE"
echo "$(date): Starting backup of db_cfswitch_core" >> "$LOGFILE"

# Get backup start time for duration calculation
BACKUP_START=$(date +%s)

if $MYSQLDUMP \
-u "$USER" \
-p"$PASSWORD" \
-h "$HOST" \
--databases db_cfswitch_core \
--single-transaction \
--events \
--routines \
--triggers \
--no-tablespaces \
--quick \
--set-gtid-purged=OFF \
--compression-algorithms=zlib \
--column-statistics=0 \
--max-allowed-packet=512M \
2>>"$ERROR_LOG" | gzip --fast > "$BACKUP_DIR/$FILENAME"
then
    BACKUP_END=$(date +%s)
    BACKUP_DURATION=$((BACKUP_END-BACKUP_START))
    
    if [ -s "$BACKUP_DIR/$FILENAME" ]; then
        BACKUP_STATUS="SUCCESS"
        # Get backup file size
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
        BACKUP_SIZE_BYTES=$(stat -c%s "$BACKUP_DIR/$FILENAME")
        
        echo "$(date): Backup completed successfully. Size: $BACKUP_SIZE" >> "$LOGFILE"
        
        # --------------------------------------------------------------------
        # UPLOAD TO AZURE BLOB
        # --------------------------------------------------------------------
        
        echo "$(date): Starting upload to Azure Blob Storage" >> "$LOGFILE"
        echo "$(date): Source: $BACKUP_DIR/$FILENAME" >> "$LOGFILE"
        echo "$(date): Destination: $FULL_CONTAINER_URL/$DEST_PATH" >> "$LOGFILE"
        
        UPLOAD_START=$(date +%s)
        
        # Check if azcopy exists
        if ! command -v "$AZCOPY" &> /dev/null && ! [ -f "$AZCOPY" ]; then
            echo "$(date): ERROR - azcopy not found at $AZCOPY" >> "$LOGFILE"
            echo "azcopy not found at $AZCOPY. Please install azcopy or check the path." >> "$ERROR_LOG"
            UPLOAD_STATUS="FAILED"
            FINAL_STATUS="PARTIAL"
        else
            # Upload with proper URL format
            $AZCOPY copy \
            "$BACKUP_DIR/$FILENAME" \
            "$FULL_CONTAINER_URL/$DEST_PATH" \
            --overwrite=true > "$AZCOPY_LOG" 2>&1
            
            UPLOAD_EXIT_CODE=$?
            UPLOAD_END=$(date +%s)
            UPLOAD_DURATION=$((UPLOAD_END-UPLOAD_START))
            
            # Capture azcopy output for email
            AZCOPY_OUTPUT=$(cat "$AZCOPY_LOG" 2>/dev/null)
            
            if [ $UPLOAD_EXIT_CODE -eq 0 ]; then
                UPLOAD_STATUS="SUCCESS"
                FINAL_STATUS="SUCCESS"
                echo "$(date): Upload completed successfully" >> "$LOGFILE"
                
                # --------------------------------------------------------------------
                # CLEANUP LOCAL BACKUP AFTER SUCCESSFUL UPLOAD
                # --------------------------------------------------------------------
                echo "$(date): Removing local backup file after successful upload" >> "$LOGFILE"
                rm -f "$BACKUP_DIR/$FILENAME"
                echo "$(date): Local backup file removed: $BACKUP_DIR/$FILENAME" >> "$LOGFILE"
                
            else
                UPLOAD_STATUS="FAILED"
                FINAL_STATUS="PARTIAL"
                echo "$(date): Upload failed with exit code $UPLOAD_EXIT_CODE" >> "$LOGFILE"
                echo "$(date): AzCopy error output:" >> "$LOGFILE"
                echo "$AZCOPY_OUTPUT" >> "$LOGFILE"
                echo "Azure Blob upload failed. Exit code: $UPLOAD_EXIT_CODE" >> "$ERROR_LOG"
                echo "AzCopy output:" >> "$ERROR_LOG"
                echo "$AZCOPY_OUTPUT" >> "$ERROR_LOG"
            fi
        fi
        
    else
        BACKUP_STATUS="FAILED - Empty file"
        echo "$(date): Backup file is empty" >> "$LOGFILE"
        echo "Backup file is empty" >> "$ERROR_LOG"
    fi
else
    BACKUP_STATUS="FAILED"
    echo "$(date): mysqldump failed" >> "$LOGFILE"
    echo "mysqldump failed. Check error log." >> "$ERROR_LOG"
fi

# --------------------------------------------------------------------
# BLOB RETENTION - KEEP ONLY LATEST 7 BACKUP FILES IN CONTAINER
# --------------------------------------------------------------------

echo "$(date): Running blob retention policy (keeping latest 7 in container)" >> "$LOGFILE"

# List all blobs in the container, sort by date (oldest first), skip first 7 (keep them), delete the rest
if [ "$UPLOAD_STATUS" = "SUCCESS" ] || [ "$UPLOAD_STATUS" = "FAILED" ]; then
    # List all blobs in Core_DB path, get only the names, sort by date (oldest first)
    # We'll use azcopy to list and then delete old ones
    
    # Create a temp file to store blob list
    BLOB_LIST="/tmp/blob_list.txt"
    > "$BLOB_LIST"
    
    # List all blobs in the Core_DB directory
    $AZCOPY list "${FULL_CONTAINER_URL}/Core_DB/" > "$BLOB_LIST" 2>&1
    
    if [ $? -eq 0 ]; then
        # Extract blob names, sort by date (assuming naming convention with timestamp)
        # Extract only .gz files and sort them by date (oldest first)
        BLOBS_TO_DELETE=$(grep "\.gz" "$BLOB_LIST" | awk '{print $NF}' | sort | head -n -7 2>/dev/null)
        
        if [ -n "$BLOBS_TO_DELETE" ]; then
            echo "$BLOBS_TO_DELETE" | while read -r blob; do
                if [ -n "$blob" ]; then
                    echo "$(date): Removing old blob: $blob" >> "$LOGFILE"
                    $AZCOPY remove "${FULL_CONTAINER_URL}/${blob}" >> "$LOGFILE" 2>&1
                fi
            done
            echo "$(date): Blob retention completed" >> "$LOGFILE"
        else
            echo "$(date): No old blobs to remove (keeping 7 latest)" >> "$LOGFILE"
        fi
    else
        echo "$(date): Failed to list blobs for retention policy" >> "$LOGFILE"
    fi
    
    rm -f "$BLOB_LIST"
fi

# --------------------------------------------------------------------
# CALCULATE TOTAL DURATION
# --------------------------------------------------------------------

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME-START_TIME))

TOTAL_DURATION=$(printf '%02d:%02d:%02d' \
$((TOTAL_TIME/3600)) \
$((TOTAL_TIME%3600/60)) \
$((TOTAL_TIME%60)))

BACKUP_DURATION_FORMATTED=$(printf '%02d:%02d:%02d' \
$((BACKUP_DURATION/3600)) \
$((BACKUP_DURATION%3600/60)) \
$((BACKUP_DURATION%60)))

if [ -n "$UPLOAD_DURATION" ]; then
    UPLOAD_DURATION_FORMATTED=$(printf '%02d:%02d:%02d' \
    $((UPLOAD_DURATION/3600)) \
    $((UPLOAD_DURATION%3600/60)) \
    $((UPLOAD_DURATION%60)))
else
    UPLOAD_DURATION_FORMATTED="N/A"
fi

# --------------------------------------------------------------------
# SEND EMAIL - Professional Report
# --------------------------------------------------------------------

{
echo "From: $MAIL_FROM"
echo "To: $MAIL_TO"
echo "Subject: $MAIL_SUBJECT [$FINAL_STATUS] - $(date +'%Y-%m-%d %H:%M:%S')"
echo "MIME-Version: 1.0"
echo "Content-Type: text/html"
echo

echo "<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Backup Report</title>
    <style>
        /* Reset styles */
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #2c3e50;
            margin: 0;
            padding: 20px;
            background-color: #f0f2f5;
        }
        
        .container {
            max-width: 900px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #1a2a6c, #2a5298);
            color: #ffffff;
            padding: 30px 40px;
            border-bottom: 5px solid #ff6b35;
        }
        
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 600;
            letter-spacing: 0.5px;
        }
        
        .header .subtitle {
            font-size: 14px;
            opacity: 0.9;
            margin-top: 5px;
        }
        
        .header .timestamp {
            font-size: 13px;
            opacity: 0.8;
            margin-top: 8px;
        }
        
        .content {
            padding: 30px 40px 20px;
        }
        
        /* Status Banner */
        .status-banner {
            padding: 20px 25px;
            border-radius: 8px;
            margin-bottom: 25px;
            border-left: 6px solid;
        }
        
        .status-success {
            background: #d4edda;
            border-color: #28a745;
            color: #155724;
        }
        
        .status-partial {
            background: #fff3cd;
            border-color: #ffc107;
            color: #856404;
        }
        
        .status-failed {
            background: #f8d7da;
            border-color: #dc3545;
            color: #721c24;
        }
        
        .status-banner h2 {
            margin: 0 0 5px 0;
            font-size: 20px;
            font-weight: 600;
        }
        
        .status-banner p {
            margin: 5px 0;
            font-size: 14px;
        }
        
        .status-banner .highlight {
            font-weight: 600;
            background: rgba(255,255,255,0.3);
            padding: 2px 8px;
            border-radius: 4px;
        }
        
        .action-required {
            background: #fff3cd;
            border: 1px solid #ffc107;
            padding: 12px 18px;
            border-radius: 6px;
            margin-top: 10px;
            font-weight: 500;
        }
        
        /* Section Headers */
        .section-title {
            font-size: 18px;
            font-weight: 600;
            color: #1a2a6c;
            margin: 25px 0 15px 0;
            padding-bottom: 8px;
            border-bottom: 2px solid #e9ecef;
            display: flex;
            align-items: center;
        }
        
        .section-title .badge {
            background: #2a5298;
            color: white;
            font-size: 11px;
            padding: 2px 10px;
            border-radius: 12px;
            margin-left: 10px;
        }
        
        /* Tables */
        .info-table {
            width: 100%;
            border-collapse: collapse;
            margin: 10px 0 20px 0;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        }
        
        .info-table tr {
            transition: background-color 0.2s;
        }
        
        .info-table tr:hover {
            background-color: #f8f9fa;
        }
        
        .info-table td {
            padding: 12px 18px;
            border-bottom: 1px solid #e9ecef;
            font-size: 14px;
        }
        
        .info-table .label {
            font-weight: 600;
            color: #495057;
            width: 35%;
            background-color: #f8f9fa;
        }
        
        .info-table .value {
            color: #212529;
            width: 65%;
        }
        
        .info-table .value code {
            background: #f1f3f5;
            padding: 3px 8px;
            border-radius: 4px;
            font-family: 'Consolas', 'Courier New', monospace;
            font-size: 13px;
            color: #d63384;
        }
        
        .info-table tr:last-child td {
            border-bottom: none;
        }
        
        /* Status indicators */
        .status-indicator {
            display: inline-block;
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .status-indicator.success {
            background: #d4edda;
            color: #155724;
        }
        
        .status-indicator.failed {
            background: #f8d7da;
            color: #721c24;
        }
        
        .status-indicator.partial {
            background: #fff3cd;
            color: #856404;
        }
        
        /* Error boxes */
        .error-box {
            background: #f8d7da;
            padding: 15px 20px;
            border-radius: 8px;
            border-left: 4px solid #dc3545;
            margin: 10px 0 20px 0;
        }
        
        .error-box pre {
            margin: 8px 0 0 0;
            white-space: pre-wrap;
            word-wrap: break-word;
            font-family: 'Consolas', 'Courier New', monospace;
            font-size: 13px;
            color: #721c24;
            background: rgba(255,255,255,0.5);
            padding: 10px;
            border-radius: 4px;
        }
        
        .info-box {
            background: #d1ecf1;
            padding: 15px 20px;
            border-radius: 8px;
            border-left: 4px solid #17a2b8;
            margin: 10px 0 20px 0;
        }
        
        .info-box p {
            margin: 5px 0;
        }
        
        /* Retention box */
        .retention-box {
            background: linear-gradient(135deg, #f8f9fa, #e9ecef);
            padding: 18px 22px;
            border-radius: 8px;
            margin: 10px 0 20px 0;
            border: 1px solid #dee2e6;
        }
        
        .retention-box p {
            margin: 6px 0;
            font-size: 14px;
        }
        
        .retention-box .count {
            display: inline-block;
            background: #1a2a6c;
            color: white;
            padding: 2px 12px;
            border-radius: 12px;
            font-size: 13px;
            font-weight: 600;
        }
        
        /* Footer */
        .footer {
            background: #f8f9fa;
            padding: 20px 40px;
            border-top: 1px solid #e9ecef;
            text-align: center;
        }
        
        .footer .signature {
            font-size: 14px;
            color: #495057;
        }
        
        .footer .signature strong {
            color: #1a2a6c;
        }
        
        .footer .note {
            font-size: 12px;
            color: #868e96;
            margin-top: 8px;
        }
        
        .footer .divider {
            border: 0;
            border-top: 1px solid #dee2e6;
            margin: 15px 0;
        }
        
        /* Responsive */
        @media (max-width: 600px) {
            .header, .content, .footer {
                padding: 20px;
            }
            
            .info-table .label {
                width: 40%;
            }
            
            .info-table .value {
                width: 60%;
            }
        }
    </style>
</head>
<body>
    <div class='container'>
        <!-- Header -->
        <div class='header'>
            <h1>CredoPay Core Database Backup Report</h1>
            <div class='subtitle'>MySQL Database Backup and Azure Blob Storage Upload</div>
            <div class='timestamp'>Generated: $(date +'%Y-%m-%d %H:%M:%S %Z')</div>
        </div>
        
        <!-- Content -->
        <div class='content'>"

# Status Banner
if [ "$FINAL_STATUS" = "SUCCESS" ]; then
    echo "
            <div class='status-banner status-success'>
                <h2>Backup Completed Successfully</h2>
                <p>All operations (Database Backup + Azure Blob Upload) completed successfully.</p>
                <p style='margin-top:8px; font-size:13px;'>
                    <strong>Backup Size:</strong> $BACKUP_SIZE &nbsp;|&nbsp; 
                    <strong>Total Duration:</strong> $TOTAL_DURATION
                </p>
            </div>"
elif [ "$FINAL_STATUS" = "PARTIAL" ]; then
    echo "
            <div class='status-banner status-partial'>
                <h2>Backup Partially Completed</h2>
                <p><strong>Database backup was created successfully</strong> but upload to Azure Blob Storage <strong>FAILED</strong>.</p>
                <p style='margin-top:5px;'>
                    <span class='highlight'>Local Path:</span> <code style='background:#fff;padding:2px 8px;border-radius:4px;'>$BACKUP_DIR/$FILENAME</code>
                </p>
                <div class='action-required'>
                    <strong>Action Required:</strong> Manual intervention required for uploading to Azure Blob Storage.
                </div>
            </div>"
else
    echo "
            <div class='status-banner status-failed'>
                <h2>Backup Failed</h2>
                <p>The database backup process failed. Please check the error details below.</p>
            </div>"
fi

# Backup Details
echo "
            <div class='section-title'>
                Backup Details
                <span class='badge'>Information</span>
            </div>
            
            <table class='info-table'>
                <tr>
                    <td class='label'>Hostname</td>
                    <td class='value'><strong>$HOSTNAME</strong></td>
                </tr>
                <tr>
                    <td class='label'>Database</td>
                    <td class='value'><code>db_cfswitch_core</code></td>
                </tr>
                <tr>
                    <td class='label'>Backup Date and Time</td>
                    <td class='value'>$(date +'%Y-%m-%d %H:%M:%S')</td>
                </tr>
                <tr>
                    <td class='label'>Backup File</td>
                    <td class='value'><code>$FILENAME</code></td>
                </tr>"

if [ "$BACKUP_STATUS" = "SUCCESS" ] || [ "$FINAL_STATUS" = "PARTIAL" ]; then
    echo "
                <tr>
                    <td class='label'>Local Path</td>
                    <td class='value'><code>$BACKUP_DIR/$FILENAME</code></td>
                </tr>"
fi

echo "
                <tr>
                    <td class='label'>Backup Size</td>
                    <td class='value'><strong>${BACKUP_SIZE:-N/A}</strong></td>
                </tr>
                <tr>
                    <td class='label'>Destination</td>
                    <td class='value'>Azure Blob Storage</td>
                </tr>
                <tr>
                    <td class='label'>Container</td>
                    <td class='value'><code>coredbbackups</code></td>
                </tr>
                <tr>
                    <td class='label'>Blob Path</td>
                    <td class='value'><code>Core_DB/${MONTH}/${FILENAME}</code></td>
                </tr>
            </table>"

# Duration Details
echo "
            <div class='section-title'>
                Duration Details
                <span class='badge'>Timing</span>
            </div>
            
            <table class='info-table'>
                <tr>
                    <td class='label'>Backup Duration</td>
                    <td class='value'><strong>$BACKUP_DURATION_FORMATTED</strong> (HH:MM:SS)</td>
                </tr>"

if [ -n "$UPLOAD_DURATION" ] && [ "$UPLOAD_STATUS" != "FAILED" ]; then
    echo "
                <tr>
                    <td class='label'>Upload Duration</td>
                    <td class='value'><strong>$UPLOAD_DURATION_FORMATTED</strong> (HH:MM:SS)</td>
                </tr>"
fi

echo "
                <tr>
                    <td class='label'>Total Duration</td>
                    <td class='value'><strong>$TOTAL_DURATION</strong> (HH:MM:SS)</td>
                </tr>
            </table>"

# Status Summary
echo "
            <div class='section-title'>
                Status Summary
                <span class='badge'>Result</span>
            </div>
            
            <table class='info-table'>
                <tr>
                    <td class='label'>Backup Status</td>
                    <td class='value'>
                        <span class='status-indicator $(echo "$BACKUP_STATUS" | tr '[:upper:]' '[:lower:]' | cut -d' ' -f1)'>
                            $BACKUP_STATUS
                        </span>
                    </td>
                </tr>
                <tr>
                    <td class='label'>Upload Status</td>
                    <td class='value'>
                        <span class='status-indicator $(echo "$UPLOAD_STATUS" | tr '[:upper:]' '[:lower:]')'>
                            $UPLOAD_STATUS
                        </span>
                    </td>
                </tr>
                <tr style='background: #e7f3ff; font-weight: 600;'>
                    <td class='label'>Final Status</td>
                    <td class='value'>
                        <span class='status-indicator $(echo "$FINAL_STATUS" | tr '[:upper:]' '[:lower:]')'>
                            $FINAL_STATUS
                        </span>
                    </td>
                </tr>
            </table>"

# Errors/Warnings
if [ -s "$ERROR_LOG" ]; then
    echo "
            <div class='section-title'>
                Warnings and Errors
                <span class='badge'>from mysqldump</span>
            </div>
            
            <div class='error-box'>
                <pre>$(cat "$ERROR_LOG")</pre>
            </div>"
fi

# AzCopy Errors
if [ "$UPLOAD_STATUS" = "FAILED" ] && [ -s "$AZCOPY_LOG" ]; then
    echo "
            <div class='section-title'>
                AzCopy Error Details
                <span class='badge'>Upload Failed</span>
            </div>
            
            <div class='error-box'>
                <p style='font-weight:600;margin-bottom:8px;'>Exit Code: $UPLOAD_EXIT_CODE</p>
                <pre>$(cat "$AZCOPY_LOG")</pre>
            </div>"
fi

# Retention Policy
echo "
            <div class='section-title'>
                Retention Policy
                <span class='badge'>Auto Cleanup</span>
            </div>
            
            <div class='retention-box'>
                <p><strong>Policy:</strong> Keeping latest 7 backup files in Azure Blob Storage. Older files are automatically removed.</p>
                <p><strong>Location:</strong> <code>Core_DB/</code> in container</p>
                <p style='margin-top:10px;'>
                    <span class='count'>Keeping 7 latest backups</span>
                </p>
            </div>"

# Footer
echo "
            <div style='margin-top: 30px;'>
                <hr style='border: none; border-top: 2px solid #e9ecef;'>
                <p style='font-size: 13px; color: #6c757d;'>
                    <strong>Note:</strong> This is an automated report generated by the MySQL backup system.
                </p>
            </div>
        </div>
        
        <!-- Footer -->
        <div class='footer'>
            <div class='signature'>
                <strong>Regards,</strong><br>
                MySQL DBA Team<br>
                ${CLIENT_NAME}
            </div>
            <hr class='divider'>
            <div class='note'>
                This is an automated message. Please do not reply to this email.
            </div>
        </div>
    </div>
</body>
</html>"

} | $SENDMAIL -t

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------

rm -f "$ERROR_LOG"
rm -f "$AZCOPY_LOG"

echo "$(date): Script completed with status: $FINAL_STATUS" >> "$LOGFILE"
echo "$(date): ==========================================" >> "$LOGFILE"

# Exit with appropriate code
if [ "$FINAL_STATUS" = "SUCCESS" ]; then
    exit 0
else
    exit 1
fi
