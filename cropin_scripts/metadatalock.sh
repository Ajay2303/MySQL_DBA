#!/bin/bash

# === CONFIGURATION ===
USER="jana"
PASSWORD="J@n@876#"
HOST="productionmysql-new.cewqmdlrwgkt.ap-southeast-1.rds.amazonaws.com"
PORT=3306
EMAIL="mysqltechsupport@geopits.com,dcc@geopits.com"
HOSTNAME="Cropin"

# === FILES ===
TMPFILE="/home/mysqladmin/cropin/mdl/metadata_lock_status.html"
FLAGFILE="/home/mysqladmin/cropin/mdl/metadata_lock_flag"
QUERYFILE="/home/mysqladmin/cropin/mdl/metadata_lock_last_queries.txt"

# === DATE ===
DATE=$(date "+%Y-%m-%d %H:%M:%S")

# === GET LOCKED QUERIES ===
LOCKED_QUERIES=$(mysql -u"$USER" -p'J@n@876#' -h"$HOST" -P"$PORT" -e "SHOW FULL PROCESSLIST;" 2>/dev/null | awk -F'\t' '
NR > 1 && tolower($7) ~ /metadata lock/ {
    gsub(/</, "&lt;", $8); gsub(/>/, "&gt;", $8);  # Escape HTML
    printf "%s|%s|%s|%s|%s|%s|%s|%s\n", $1, $2, $3, $4, $5, $6, $7, $8
}')

LOCK_EXISTS=0
[ -n "$LOCKED_QUERIES" ] && LOCK_EXISTS=1

[ -f "$FLAGFILE" ] && LAST_STATE=$(cat "$FLAGFILE") || LAST_STATE=0

### ========== CASE 1: NEW LOCK DETECTED ==========
if [[ "$LOCK_EXISTS" -eq 1 && "$LAST_STATE" -eq 0 ]]; then
    echo "1" > "$FLAGFILE"
    echo "$LOCKED_QUERIES" > "$QUERYFILE"

    {
        echo "<html><body style='font-family:Arial;'>"
        echo "<h2 style='color:#B22222;'> MySQL Metadata Lock - ALERT</h2>"
        echo "<p><strong>Date:</strong> $DATE</p>"
        echo "<p><strong>Host:</strong> $HOSTNAME</p>"
        echo "<p>The following queries are waiting for a <strong>metadata lock</strong>:</p>"
        echo "<table border='1' cellpadding='6' cellspacing='0' style='border-collapse:collapse; font-size:14px;'>"
        echo "<tr style='background-color:#f8d7da; color:#721c24;'>
                <th>Id</th><th>User</th><th>Host</th><th>DB</th>
                <th>Command</th><th>Time</th><th>State</th><th>Query</th></tr>"

        while IFS="|" read -r id user host db cmd time state info; do
            echo "<tr>
                    <td>$id</td><td>$user</td><td>$host</td><td>${db:-NULL}</td>
                    <td>$cmd</td><td>$time</td><td>$state</td>
                    <td><pre style='margin:0; font-family:monospace;'>${info:0:200}</pre></td>
                  </tr>"
        done <<< "$LOCKED_QUERIES"

        echo "</table></body></html>"
    } > "$TMPFILE"

    mail -a "Content-Type: text/html" -s "[ALERT] MySQL Metadata Lock Detected on $HOSTNAME" "$EMAIL" < "$TMPFILE"
fi

### ========== CASE 2: LOCK RESOLVED ==========
if [[ "$LOCK_EXISTS" -eq 0 && "$LAST_STATE" -eq 1 ]]; then
    echo "0" > "$FLAGFILE"

    {
        echo "<html><body style='font-family:Arial;'>"
        echo "<h2 style='color:green;'> MySQL Metadata Lock - RESOLVED</h2>"
        echo "<p><strong>Date:</strong> $DATE</p>"
        echo "<p><strong>Host:</strong> $HOSTNAME</p>"
        echo "<p>The metadata lock has been <strong>cleared</strong>. Below are the previously blocked queries:</p>"
        echo "<table border='1' cellpadding='6' cellspacing='0' style='border-collapse:collapse; font-size:14px;'>"
        echo "<tr style='background-color:#d4edda; color:#155724;'>
                <th>Id</th><th>User</th><th>Host</th><th>DB</th>
                <th>Command</th><th>Time</th><th>State</th><th>Query</th></tr>"

        while IFS="|" read -r id user host db cmd time state info; do
            echo "<tr>
                    <td>$id</td><td>$user</td><td>$host</td><td>${db:-NULL}</td>
                    <td>$cmd</td><td>$time</td><td>$state</td>
                    <td><pre style='margin:0; font-family:monospace;'>${info:0:200}</pre></td>
                  </tr>"
        done < "$QUERYFILE"

        echo "</table></body></html>"
    } > "$TMPFILE"

    mail -a "Content-Type: text/html" -s "[RESOLVED] MySQL Metadata Lock Cleared on $HOSTNAME" "$EMAIL" < "$TMPFILE"

    rm -f "$QUERYFILE"
fi
