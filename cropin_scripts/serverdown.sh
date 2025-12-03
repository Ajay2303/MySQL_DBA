#!/bin/bash

# ------------------------------------------------------------------
#  MySQL HEALTH MONITORING SCRIPT (PRODUCTION-GRADE)
#  Sends DOWN alerts and RESOLVED UP alerts with advanced HTML UI.
#  Includes alert-state tracking to prevent repeated notifications.
# ------------------------------------------------------------------

# MySQL Credentials
MYSQL_USER="jana"
MYSQL_PASSWORD="J@n@876#"
MYSQL_HOST="productionmysql-new.cewqmdlrwgkt.ap-southeast-1.rds.amazonaws.com"

# Client Information
CLIENT_NAME="Cropin"
JUMPSERVER_HOSTNAME="Cropin Jumpserver"

# Email Recipients
EMAIL_ADDRESSES="mysqltechsupport@geopits.com,dcc@geopits.com"

# IP Details
PUBLIC_IP=$(curl -s ifconfig.me)

# Alert State File (tracks last server status)
STATE_FILE="/home/mysqladmin/cropin/log/mysql_server_state.txt"

# ------------------------------------------------------------------
#  HTML Template (DOWN ALERT)
# ------------------------------------------------------------------
generate_down_html() {
cat <<EOF
<html>
<body style="font-family: Arial, sans-serif; color: #333;">

<div style="background:#b30000; color:white; padding:15px; font-size:18px; font-weight:bold; border-radius:6px;">
     CRITICAL INCIDENT: MySQL Server Down
</div>

<p>Hello Team,</p>

<p style="font-size:15px;">
Our DBAs have detected that the MySQL server <b>$MYSQL_HOST</b> is currently 
<span style="color:#b30000; font-weight:bold;">UNREACHABLE</span>.
</p>

<h3 style="color:#003366; border-left:4px solid #003366; padding-left:8px;">
Incident Summary
</h3>

<table style="border-collapse: collapse; width: 70%; margin-top:10px;">
<tr style="background-color: #003366; color: white;">
    <th style="padding:10px; border:1px solid #ddd;">Jumpserver Hostname</th>
    <th style="padding:10px; border:1px solid #ddd;">Public IP</th>
    <th style="padding:10px; border:1px solid #ddd;">RDS Hostname</th>
</tr>
<tr>
    <td style="padding:10px; border:1px solid #ddd;">$JUMPSERVER_HOSTNAME</td>
    <td style="padding:10px; border:1px solid #ddd;">$PUBLIC_IP</td>
    <td style="padding:10px; border:1px solid #ddd;">$MYSQL_HOST</td>
</tr>
</table>

<br>

<div style="background:#fff3cd; border-left:5px solid #ffcc00; padding:12px; border-radius:4px;">
Our support team is actively investigating the issue. Updates will follow shortly.
</div>

<p style="font-size:14px;">
Please treat this as a <b>high priority</b> incident and monitor closely until resolved.
</p>

<br>
<p>Regards,<br>
<b>MySQL Support Team</b></p>

</body>
</html>
EOF
}

# ------------------------------------------------------------------
#  HTML Template (UP / RESOLVED ALERT)
# ------------------------------------------------------------------
generate_up_html() {
cat <<EOF
<html>
<body style="font-family: Arial, sans-serif; color: #333;">

<div style="background:#2e7d32; color:white; padding:15px; font-size:18px; font-weight:bold; border-radius:6px;">
    RESOLVED: MySQL Server is Back Online
</div>

<p>Hello Team,</p>

<p style="font-size:15px;">
We would like to inform you that the MySQL server <b>$MYSQL_HOST</b> is now 
<span style="color:#2e7d32; font-weight:bold;">UP & RUNNING</span>.
</p>

<h3 style="color:#003366; border-left:4px solid #003366; padding-left:8px;">
Recovery Summary
</h3>

<table style="border-collapse: collapse; width: 70%; margin-top:10px;">
<tr style="background-color: #003366; color: white;">
    <th style="padding:10px; border:1px solid #ddd;">Jumpserver Hostname</th>
    <th style="padding:10px; border:1px solid #ddd;">Public IP</th>
    <th style="padding:10px; border:1px solid #ddd;">RDS Hostname</th>
</tr>
<tr>
    <td style="padding:10px; border:1px solid #ddd;">$JUMPSERVER_HOSTNAME</td>
    <td style="padding:10px; border:1px solid #ddd;">$PUBLIC_IP</td>
    <td style="padding:10px; border:1px solid #ddd;">$MYSQL_HOST</td>
</tr>
</table>

<br>

<div style="background:#e8f5e9; border-left:5px solid #2e7d32; padding:12px; border-radius:4px;">
The database is responding normally and services are restored.
</div>

<p style="font-size:14px;">
This alert is being sent because a prior DOWN alert was triggered.
</p>

<br>
<p>Regards,<br>
<b>MySQL Support Team</b></p>

</body>
</html>
EOF
}

# ------------------------------------------------------------------
#  MySQL Health Check
# ------------------------------------------------------------------
mysql -u "$MYSQL_USER" -p'J@n@876#' -h "$MYSQL_HOST" -e "SELECT 1" &> /dev/null
MYSQL_STATUS=$?   # 0 = UP, non-zero = DOWN

LAST_STATE="UNKNOWN"
[ -f "$STATE_FILE" ] && LAST_STATE=$(cat "$STATE_FILE")

# ------------------------------------------------------------------
#  DOWN ALERT LOGIC
# ------------------------------------------------------------------
if [ $MYSQL_STATUS -ne 0 ]; then
    if [ "$LAST_STATE" != "DOWN" ]; then
        
        SUBJECT="CRITICAL: $CLIENT_NAME - MySQL Server DOWN ($MYSQL_HOST)"

        EMAIL_CONTENT=$(generate_down_html)

        {
            echo "Subject: $SUBJECT"
            echo "Content-Type: text/html"
            echo ""
            echo "$EMAIL_CONTENT"
        } | sendmail -t "$EMAIL_ADDRESSES"

        echo "DOWN" > "$STATE_FILE"
        echo "DOWN Alert Sent."
    fi
    exit
fi

# ------------------------------------------------------------------
#  UP ALERT LOGIC
# ------------------------------------------------------------------
if [ "$LAST_STATE" == "DOWN" ] && [ $MYSQL_STATUS -eq 0 ]; then
    
    SUBJECT="RESOLVED: $CLIENT_NAME - MySQL Server UP ($MYSQL_HOST)"

    EMAIL_CONTENT=$(generate_up_html)

    {
        echo "Subject: $SUBJECT"
        echo "Content-Type: text/html"
        echo ""
        echo "$EMAIL_CONTENT"
    } | sendmail -t "$EMAIL_ADDRESSES"

    echo "UP" > "$STATE_FILE"
    echo "UP Alert Sent."
fi

