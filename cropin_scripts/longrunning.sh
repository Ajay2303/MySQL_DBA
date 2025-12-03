#!/bin/bash

# Configuration
DB_HOST="productionmysql-new.cewqmdlrwgkt.ap-southeast-1.rds.amazonaws.com"
DB_USER="jana"
#DB_PWD="J@n@876#"

EMAIL="mysqltechsupport@geopits.com,dcc@geopits.com"
DURATION_THRESHOLD=600
CLIENT_NAME="Cropin-MySQL"

# Host Info
#JUMPSERVER_HOSTNAME=
PUBLIC_IP=$(curl -s ifconfig.me)
EXCLUDE_DB="mysql|information_schema|performance_schema|sys"

# State tracking files
PREV_QUERY_IDS_FILE="/home/mysqladmin/cropin/log/long_running_query_ids.txt"
CURR_QUERY_IDS_FILE="/home/mysqladmin/cropin/log/current_query_ids.txt"
touch "$PREV_QUERY_IDS_FILE"
> "$CURR_QUERY_IDS_FILE"

# Get list of all databases excluding system ones
DATABASES=$(mysql -u "$DB_USER" -h "$DB_HOST" -p'J@n@876#' -e "SHOW DATABASES;" --batch --skip-column-names | grep -Ev "$EXCLUDE_DB")

# Start HTML content
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

# Create a variable to store all query tables
QUERY_TABLES=""

for DB in $DATABASES; do
    QUERY="SELECT ID, USER, HOST, DB, COMMAND, TIME, INFO FROM INFORMATION_SCHEMA.PROCESSLIST WHERE COMMAND != 'Sleep' AND TIME > $DURATION_THRESHOLD AND DB = '$DB';"
    HTML_OUTPUT=$(mysql -u "$DB_USER" -h "$DB_HOST" -p'J@n@876#' -e "$QUERY" --batch --skip-column-names)

    if [ -n "$HTML_OUTPUT" ]; then
        queries_found=true
        echo "$HTML_OUTPUT" | awk '{print $1}' >> "$CURR_QUERY_IDS_FILE"

        query_ids=$(echo "$HTML_OUTPUT" | awk '{print $1}' | head -n 10 | tr '\n' ',' | sed 's/,$//')
        query_id_subject="${query_id_subject:+$query_id_subject,}$query_ids"

        CURRENT_TABLE="<h3>Database: $DB</h3>
        <table>
            <thead>
                <tr class='red-header'>
                    <th>Query ID</th>
                    <th>User</th>
                    <th>Host</th>
                    <th>Database</th>
                    <th>Command</th>
                    <th>Duration (s)</th>
                    <th>Query</th>
                </tr>
            </thead>
            <tbody>"

        while IFS=$'\t' read -r query_id user host db command duration query; do
            CURRENT_TABLE+="<tr>
                <td>$query_id</td>
                <td>$user</td>
                <td>$host</td>
                <td>$db</td>
                <td>$command</td>
                <td>$duration</td>
                <td>$query</td>
            </tr>"
        done <<< "$HTML_OUTPUT"

        CURRENT_TABLE+="</tbody></table>"
        QUERY_TABLES+="$CURRENT_TABLE"
    fi
done

# Append all query tables to the HTML content
HTML_CONTENT+="$QUERY_TABLES"

# Add the standard response text only once at the end
if $queries_found; then
    HTML_CONTENT+="<p>These queries have been running for over $DURATION_THRESHOLD seconds. We recommend terminating them to avoid potential performance issues.</p>
    <p>Please confirm if you would like us to proceed with terminating the queries, or if you prefer to allow them to complete their execution.</p>
    <p>Kindly provide your confirmation, and our team will take the necessary action based on your response.</p>"
fi

HTML_CONTENT+="<p><strong>Regards,</strong></p>
<p>MySQL Monitoring Team.</p>
</body></html>"

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

# Send current long-running alert
if $queries_found; then
    send_email_alert "$CLIENT_NAME - Long Running Queries (IDs: $query_id_subject)" "$HTML_CONTENT"
    logger "MySQL long-running query alert sent"
fi

# Find resolved queries
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
    <p>Upon further observation, the Query ID is no longer running, and no alerts were received for the mentioned Query ID. Therefore, the issue has been resolved, and we are proceeding to close the ticket. If you need any further assistance, please feel free to reach out.</p>

    <table>
        <thead>
            <tr class='green-header'><th>Resolved Query ID</th></tr>
        </thead>
        <tbody>"

    while read -r qid; do
        COMPLETED_HTML+="<tr><td>$qid</td></tr>"
    done <<< "$no_longer_running"

    COMPLETED_HTML+="</tbody></table>
    <p><strong>Regards,</strong></p>
    <p>MySQL Monitoring Team.</p>
    </body></html>"

    send_email_alert "$CLIENT_NAME - Resolved Long Running Queries on $DB_HOST" "$COMPLETED_HTML"
    logger "Resolved query notification sent"
fi

# Rotate state files
mv "$CURR_QUERY_IDS_FILE" "$PREV_QUERY_IDS_FILE"
