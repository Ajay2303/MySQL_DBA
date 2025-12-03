#!/bin/bash

##############################################################
#         Cropin MySQL - RDS Restart Detection Script
#         Fully Professional + HTML UI + Metadata
##############################################################

# MySQL Details
MYSQL_USER="jana"
MYSQL_PASS='J@n@876#'
MYSQL_HOST="productionmysql-new.cewqmdlrwgkt.ap-southeast-1.rds.amazonaws.com"

# Files
STATUS_FILE="/home/mysqladmin/cropin/restart_status.txt"
LOG_FILE="/home/mysqladmin/cropin/restart_check.log"

# Email Details
CLIENT_NAME="Cropin MySQL"
EMAIL_FROM="Cropin MySQL <mysql-alerts@geopits.com>"
EMAIL_TO="mysqltechsupport@geopits.com,dcc@geopits.com"
MAIL_SUBJECT="ALERT - ${CLIENT_NAME} - Restart Detected"

##############################################################
# Convert uptime → number of days only
##############################################################
convert_uptime_days() {
    local S=$1
    local DAYS=$((S / 86400))
    echo "${DAYS} days"
}

##############################################################
# Fetch current uptime from MySQL
##############################################################
CURRENT_UPTIME=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h "$MYSQL_HOST" \
    -N -e "SHOW GLOBAL STATUS LIKE 'Uptime';" | awk '{print $2}')

# Readable form (days only)
READABLE_CURRENT=$(convert_uptime_days "$CURRENT_UPTIME")

##############################################################
# Load previous uptime
##############################################################
if [[ -f "$STATUS_FILE" ]]; then
    PREVIOUS_UPTIME=$(cat "$STATUS_FILE")
else
    PREVIOUS_UPTIME=0
fi

READABLE_PREVIOUS=$(convert_uptime_days "$PREVIOUS_UPTIME")

##############################################################
# HTML EMAIL BODY (Your EXACT UI + modifications)
##############################################################
EMAIL_BODY=$(cat <<EOF
<!DOCTYPE html>
<html>
<head>
<style>
    body {
        background: #f4f6f8;
        font-family: Arial, Helvetica, sans-serif;
        color: #222;
        padding: 25px;
    }
    .container {
        max-width: 780px;
        margin: auto;
        background: #fff;
        padding: 25px 35px;
        border-radius: 10px;
        border-left: 8px solid #b71c1c;
        box-shadow: 0 3px 10px rgba(0,0,0,0.15);
    }
    .title {
        font-size: 24px;
        font-weight: bold;
        color: #b71c1c;
        border-bottom: 2px solid #eee;
        padding-bottom: 12px;
        margin-bottom: 25px;
    }
    .section-title {
        font-size: 17px;
        font-weight: bold;
        margin-top: 25px;
        padding-bottom: 6px;
        color: #333;
        border-bottom: 1px solid #ddd;
    }
    table {
        width: 100%;
        margin-top: 12px;
        border-collapse: collapse;
    }
    table td {
        padding: 10px 6px;
        border-bottom: 1px solid #f1f1f1;
        font-size: 15px;
    }
    .label {
        width: 230px;
        font-weight: bold;
        color: #000;
    }
    .footer {
        margin-top: 30px;
        font-size: 14px;
        color: #444;
        text-align: right;
        font-style: italic;
    }
</style>
</head>
<body>

<div class="container">

    <div class="title">${CLIENT_NAME} - Restart Detected</div>

    <div class="section-title">Restart Summary</div>
    <table>
        <tr><td class="label">Previous Uptime</td><td>${READABLE_PREVIOUS}</td></tr>
        <tr><td class="label">Current Uptime</td><td>${READABLE_CURRENT}</td></tr>
        <tr><td class="label">Detection Timestamp</td><td>$(date)</td></tr>
    </table>

    <div class="section-title">Server Details</div>
    <table>
        <tr><td class="label">Hostname</td><td>${MYSQL_HOST}</td></tr>
        <tr><td class="label">Environment</td><td>Production</td></tr>
        <tr><td class="label">Region</td><td>ap-southeast-1</td></tr>
        <tr><td class="label">Alert Source</td><td>Cropin JumpServer</td></tr>
    </table>

    <div class="section-title">Alert Metadata</div>
    <table>
        <tr><td class="label">Action Required</td><td>Review RDS Recent Events & Validate DB Health Immediately</td></tr>
    </table>

    <div class="footer">From MySQL Tech Team</div>

</div>

</body>
</html>
EOF
)

##############################################################
# Restart Detection Logic
##############################################################
if (( CURRENT_UPTIME < PREVIOUS_UPTIME )); then
    echo "$EMAIL_BODY" | mail -a "Content-Type: text/html" \
         -a "From:${EMAIL_FROM}" -s "$MAIL_SUBJECT" "$EMAIL_TO"
else
    echo "$(date) - OK - Uptime: $READABLE_CURRENT" >> "$LOG_FILE"
fi

##############################################################
# Save current uptime
##############################################################
echo "$CURRENT_UPTIME" > "$STATUS_FILE"
