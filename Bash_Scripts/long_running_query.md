# MySQL Long Running Query Monitor

This script monitors **long-running queries** in MySQL using  
`INFORMATION_SCHEMA.PROCESSLIST`.  

It sends:
-  **Alert emails** when queries exceed the duration threshold  
-  **Resolved emails** when queries are no longer running  

---

## Features
- Detects queries running longer than `$DURATION_THRESHOLD` seconds  
- Excludes system schemas (`mysql`, `information_schema`, `performance_schema`, `sys`)  
- Sends **HTML email alerts** with red/green themes  
- Tracks previously seen query IDs to avoid duplicate alerts  
- Sends a **resolved notification** once the queries complete  
- Logs activity with `logger` for syslog integration  

---
## Files Used
- **`/home/long/log/long_running_query_ids.txt`** → Previous Query IDs  
- **`/home/long/log/current_query_ids.txt`** → Current Query IDs  
---
## Script

```bash
#!/bin/bash

# Configuration
DB_HOST=""
DB_USER=""
DB_PWD=""
EMAIL=""
DURATION_THRESHOLD=
CLIENT_NAME=""
PREV_QUERY_IDS_FILE="/home/long/log/long_running_query_ids.txt"
CURR_QUERY_IDS_FILE="/home/long/log/current_query_ids.txt"

# Host Info
JUMPSERVER_HOSTNAME=$(hostname)
PUBLIC_IP=$(curl -s ifconfig.me)

# State tracking
touch "$PREV_QUERY_IDS_FILE"
> "$CURR_QUERY_IDS_FILE"

# Start HTML body
HTML_CONTENT="<html>
<head>
    <title>MySQL Long Running Queries</title>
    <style>
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th.red-header { background-color: #ffcccc; }
        th.green-header { background-color: #ccffcc; }
        td { white-space: nowrap; }
    </style>
</head>
<body>
    <p>Hello Team,</p>
    <p>Our DBAs have detected long-running queries on <strong>$DB_HOST</strong> that may impact performance.</p>
    <h2 style='color: red;'>Long Running Queries (>$DURATION_THRESHOLD seconds)</h2>
    <table>
        <thead>
            <tr class='red-header'>
                <th>Jump Server Hostname</th>
                <th>Jump Server IP</th>
                <th>DB Server Hostname</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td>$JUMPSERVER_HOSTNAME</td>
                <td>$PUBLIC_IP</td>
                <td>$DB_HOST</td>
            </tr>
        </tbody>
    </table>
"

queries_found=false
query_id_subject=""
QUERY_TABLES=""

QUERY="SELECT ID, USER, HOST, DB, COMMAND, TIME, INFO
       FROM INFORMATION_SCHEMA.PROCESSLIST
       WHERE COMMAND != 'Sleep'
         AND TIME > $DURATION_THRESHOLD
         AND DB NOT IN ('mysql','information_schema','performance_schema','sys');"

HTML_OUTPUT=$(mysql -u "$DB_USER" -h "$DB_HOST" -p"$DB_PWD" -e "$QUERY" --batch --skip-column-names)

if [ -n "$HTML_OUTPUT" ]; then
   queries_found=true
   echo "$HTML_OUTPUT" | awk '{print $1}' >> "$CURR_QUERY_IDS_FILE"

   query_ids=$(echo "$HTML_OUTPUT" | awk '{print $1}' | head -n 10 | tr '\n' ',' | sed 's/,$//')
   query_id_subject="$query_ids"

   CURRENT_TABLE="<h3>Long running query details:</h3>
   <table>
       <thead>
           <tr class='red-header'>
               <th>Query ID</th><th>User</th><th>Host</th><th>Database</th>
               <th>Command</th><th>Duration (s)</th><th>Query</th>
           </tr>
       </thead><tbody>"

    while IFS=$'\t' read -r query_id user host db command duration query; do
       CURRENT_TABLE+="<tr>
           <td>$query_id</td><td>$user</td><td>$host</td><td>$db</td>
           <td>$command</td><td>$duration</td><td>$query</td>
       </tr>"
   done <<< "$HTML_OUTPUT"

   CURRENT_TABLE+="</tbody></table>"
   QUERY_TABLES+="$CURRENT_TABLE"
fi

# Append query tables
HTML_CONTENT+="$QUERY_TABLES"

if $queries_found; then
    HTML_CONTENT+="<p>These queries have been running for over $DURATION_THRESHOLD seconds. We recommend terminating them to avoid potential performance issues.</p>
    <p>Please confirm if you would like us to proceed with terminating the queries, or if you prefer to allow them to complete their execution.</p>"
fi

HTML_CONTENT+="<p><strong>Regards,</strong><br>MySQL Monitoring Team.</p></body></html>"

send_email_alert() {
    local subject="$1"
    local html_message="$2"
    {
        echo "Subject: $subject"
        echo "Content-Type: text/html"
        echo ""
        echo "$html_message"
    } | sendmail "$EMAIL"
}

# Send current alert
if $queries_found; then
    send_email_alert "$CLIENT_NAME - Long Running Queries (IDs: $query_id_subject)" "$HTML_CONTENT"
    logger "MySQL long-running query alert sent"
fi

# Resolved queries
no_longer_running=$(comm -23 <(sort "$PREV_QUERY_IDS_FILE") <(sort "$CURR_QUERY_IDS_FILE"))

if [ -n "$no_longer_running" ]; then
    COMPLETED_HTML="<html>
    <head>
        <style>
            table { border-collapse: collapse; width: 50%; }
            th, td { border: 1px solid black; padding: 8px; text-align: left; }
            th.green-header { background-color: #ccffcc; }
        </style>
    </head>
    <body>
    <h2 style='color: green;'>Resolved Queries</h2>
    <p>Hello Team,</p>
    <p>The following queries are no longer running. The issue is considered resolved.</p>
    <table>
        <thead><tr class='green-header'><th>Resolved Query ID</th></tr></thead>
        <tbody>"

    while read -r qid; do
        COMPLETED_HTML+="<tr><td>$qid</td></tr>"
    done <<< "$no_longer_running"

    COMPLETED_HTML+="</tbody></table>
    <p><strong>Regards,</strong><br>MySQL Monitoring Team.</p>
    </body></html>"

    send_email_alert "$CLIENT_NAME - Resolved Long Running Queries on $DB_HOST" "$COMPLETED_HTML"
    logger "Resolved query notification sent"
fi

# Rotate files
mv "$CURR_QUERY_IDS_FILE" "$PREV_QUERY_IDS_FILE"
```
