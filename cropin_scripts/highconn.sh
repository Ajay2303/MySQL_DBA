#!/bin/bash

##############################################################
#         Cropin MySQL - High Connection Usage Alert Script
#         Using Same UI as Restart Alert Script
##############################################################

# MySQL Details
MYSQL_USER="jana"
MYSQL_PASS='J@n@876#'
MYSQL_HOST="productionmysql-new.cewqmdlrwgkt.ap-southeast-1.rds.amazonaws.com"

# Threshold
THRESHOLD=80   # ALERT when >= 80 connections

# Files
FLAG_FILE="/home/mysqladmin/cropin/log/high_conn_flag"
LOG_FILE="/home/mysqladmin/cropin/log/connection_check.log"

# Email Details
CLIENT_NAME="Cropin MySQL"
EMAIL_FROM="Cropin MySQL<mysqlalert2@gmail.com>"
EMAIL_TO="mysqltechsupport@geopits.com,dcc@geopits.com"

ALERT_SUBJECT="ALERT - ${CLIENT_NAME} - High MySQL Connection Usage"
RESOLVE_SUBJECT="RESOLVED - ${CLIENT_NAME} - Connection Usage Normalized"

##############################################################
# Fetch current active connections
##############################################################
CURRENT_CONN=$(mysql -u"$MYSQL_USER" -p'J@n@876#' -h "$MYSQL_HOST" \
    -N -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';" | awk '{print $2}')

##############################################################
# HTML UI (Same as Restart Alert)
##############################################################
generate_email_body() {
    local TYPE=$1   # ALERT or RESOLVED
    local COLOR=$2  # red/orange/green
    local TITLE=$3  # title text

cat <<EOF
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
        border-left: 8px solid ${COLOR};
        box-shadow: 0 3px 10px rgba(0,0,0,0.15);
    }
    .title {
        font-size: 24px;
        font-weight: bold;
        color: ${COLOR};
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

    <div class="title">High Connection Usage</div>

    <div class="section-title">Connection Summary</div>
    <table>
        <tr><td class="label">Current Active Connections</td><td>${CURRENT_CONN}</td></tr>
        <tr><td class="label">Threshold</td><td>${THRESHOLD}</td></tr>
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
        <tr><td class="label">Alert Type</td><td>${TYPE}</td></tr>
        <tr><td class="label">Action Required</td><td>Review DB load & active connections</td></tr>
    </table>

    <div class="footer">From MySQL Tech Team</div>

</div>

</body>
</html>
EOF
}

##############################################################
# Alert Logic
##############################################################
if (( CURRENT_CONN >= THRESHOLD )); then

    # If no alert triggered previously → send alert
    if [[ ! -f "$FLAG_FILE" ]]; then
        
        EMAIL_BODY=$(generate_email_body "High Connection Usage Detected" "#e65100" "${CLIENT_NAME} – High Connection Usage Alert")

        echo "$EMAIL_BODY" | mail -a "Content-Type: text/html" \
             -a "From:${EMAIL_FROM}" -s "$ALERT_SUBJECT" "$EMAIL_TO"

        echo "ALERT" > "$FLAG_FILE"
    fi

else
    # If previously alert was active → send resolved email
    if [[ -f "$FLAG_FILE" ]]; then
        
        EMAIL_BODY=$(generate_email_body "Connection Usage Normalized" "#2e7d32" "${CLIENT_NAME} – Connection Usage Resolved")

        echo "$EMAIL_BODY" | mail -a "Content-Type: text/html" \
             -a "From:${EMAIL_FROM}" -s "$RESOLVE_SUBJECT" "$EMAIL_TO"

        rm -f "$FLAG_FILE"
    fi

    echo "$(date) - OK - Connections: $CURRENT_CONN" >> "$LOG_FILE"
fi
