# MySQL Health Check Report Script

This script generates a **comprehensive HTML health report** for a MySQL server, covering **uptime, connections, queries per second, buffer pool efficiency, errors, replication, and database sizes**. The report is sent automatically via email.

---

## Features
-  **Uptime** → Shows server stability since last restart.  
-  **Connections** → Active connections, running queries, and % usage of `max_connections`.  
-  **QPS (Queries Per Second)** → Indicates workload intensity.  
-  **InnoDB Buffer Pool Efficiency** → Hit ratio to measure memory vs. disk reads.  
-  **Errors** → Tracks deadlocks and aborted client connections.  
-  **Replication** → Shows replica lag (`Seconds_Behind_Master`) or "Not a replica".  
-  **Database Sizes** → Lists all DBs by size in GB.  
-  **Top 5 Largest Databases** → Highlights heavy consumers for capacity planning.  
-  **HTML-formatted email report** with explanations for each metric.  

---

## Script Details
- Script name: `mysql_health_report.sh`
- Email body is **styled in HTML** for readability.
- Uses **`~/.my.cnf`** for authentication (no password inside script).
- Relies on `sendmail` for email delivery.

---

## Script
```bash
#!/bin/bash

# ================================
# MySQL Health Check Report Script
# ================================

CLIENT_NAME=""
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Mail settings
MAIL_TO=""
MAIL_SUBJECT="MySQL Health Report - $DATE"

# MySQL command (credentials from ~/.my.cnf)
MYSQL="mysql --batch --skip-column-names"

# ================================
# Collect Metrics
# ================================

# Uptime
UPTIME_SEC=$($MYSQL -e "SHOW GLOBAL STATUS LIKE 'Uptime';" | awk '{print $2}')
UPTIME_DAYS=$((UPTIME_SEC/86400))
UPTIME_HOURS=$(( (UPTIME_SEC%86400)/3600 ))
UPTIME_MINS=$(( (UPTIME_SEC%3600)/60 ))
UPTIME="$UPTIME_DAYS days $UPTIME_HOURS hours $UPTIME_MINS minutes"

# Connections
THREADS_CONNECTED=$($MYSQL -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';" | awk '{print $2}')
THREADS_RUNNING=$($MYSQL -e "SHOW GLOBAL STATUS LIKE 'Threads_running';" | awk '{print $2}')
MAX_CONNECTIONS=$($MYSQL -e "SHOW VARIABLES LIKE 'max_connections';" | awk '{print $2}')
CONN_USAGE=$(echo "scale=2; $THREADS_CONNECTED*100/$MAX_CONNECTIONS" | bc)

# Queries Per Second
QUERIES=$($MYSQL -e "SHOW GLOBAL STATUS LIKE 'Queries';" | awk '{print $2}')
QPS=$(echo "scale=2; $QUERIES/$UPTIME_SEC" | bc)

# InnoDB Buffer Pool
BP_READS=$($MYSQL -e "SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';" | awk '{print $2}')
BP_READ_REQUESTS=$($MYSQL -e "SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read_requests';" | awk '{print $2}')
if [ "$BP_READ_REQUESTS" -gt 0 ]; then
  BP_HIT=$(echo "scale=2; (1 - $BP_READS/$BP_READ_REQUESTS) * 100" | bc)
else
  BP_HIT="N/A"
fi

# Errors
DEADLOCKS=$($MYSQL -e "SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';" | awk '{print $2}')
DEADLOCKS=${DEADLOCKS:-0}
ABORTED_CONNECTS=$($MYSQL -e "SHOW GLOBAL STATUS LIKE 'Aborted_connects';" | awk '{print $2}')
if [ "$DEADLOCKS" -eq 0 ]; then
  DEADLOCKS="No Deadlocks"
fi

# Replication
REPL_STATUS=$($MYSQL -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Seconds_Behind_Master" | awk '{print $2}')
if [ -z "$REPL_STATUS" ]; then
  REPL_STATUS="Not a replica"
fi

# Database sizes
DB_SIZES=$($MYSQL -e "
SELECT table_schema,
       ROUND(SUM(data_length+index_length)/1024/1024/1024,2) AS size_gb
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema','performance_schema','mysql','sys')
GROUP BY table_schema
ORDER BY size_gb DESC;")

# Top 5 DBs
TOP5_DB=$($MYSQL -e "
SELECT table_schema,
       ROUND(SUM(data_length+index_length)/1024/1024/1024,2) AS size_gb
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema','performance_schema','mysql','sys')
GROUP BY table_schema
ORDER BY size_gb DESC LIMIT 5;")

# ================================
# Build HTML Report & Send Mail
# ================================
{
echo "To: $MAIL_TO"
echo "From: CredoPay MySQL <mysql@yourdomain.com>"
echo "Subject: $MAIL_SUBJECT"
echo "Content-Type: text/html"
echo ""
cat <<EOF
<html>
<head>
<style>
  body { font-family: Arial, sans-serif; font-size: 16px; }
  h2 { color: #2F4F4F; }
  table { border-collapse: collapse; width: 85%; }
  th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
  th { background-color: #f2f2f2; }
  p.explain { font-size:16px; color: #555; font-weight: bold; }
</style>
</head>
<body>
<h2>MySQL Health Report - $CLIENT_NAME</h2>
<p><b>Generated:</b> $DATE</p>

<h3>🔹 Uptime</h3>
<p>$UPTIME</p>
<p class="explain">This shows how long the MySQL server has been running without restart.</p>

<h3>🔹 Connections</h3>
<table>
<tr><th>Threads Connected</th><th>Threads Running</th><th>Max Connections</th><th>Usage %</th></tr>
<tr><td>$THREADS_CONNECTED</td><td>$THREADS_RUNNING</td><td>$MAX_CONNECTIONS</td><td>$CONN_USAGE%</td></tr>
</table>

<h3>🔹 Queries Per Second (QPS)</h3>
<p>$QPS</p>

<h3>🔹 InnoDB Buffer Pool</h3>
<table>
<tr><th>Read Requests</th><th>Disk Reads</th><th>Hit Ratio</th></tr>
<tr><td>$BP_READ_REQUESTS</td><td>$BP_READS</td><td>$BP_HIT%</td></tr>
</table>

<h3>🔹 Errors</h3>
<table>
<tr><th>Aborted Connects</th><th>Deadlocks</th></tr>
<tr><td>$ABORTED_CONNECTS</td><td>$DEADLOCKS</td></tr>
</table>

<h3>🔹 Replication</h3>
<p>$REPL_STATUS</p>

<h3>🔹 Database Sizes (GB)</h3>
<table>
<tr><th>Database</th><th>Size (GB)</th></tr>
$(echo "$DB_SIZES" | awk '{print "<tr><td>"$1"</td><td>"$2"</td></tr>"}')
</table>

<h3>🔹 Top 5 Largest Databases</h3>
<table>
<tr><th>Database</th><th>Size (GB)</th></tr>
$(echo "$TOP5_DB" | awk '{print "<tr><td>"$1"</td><td>"$2"</td></tr>"}')
</table>

<hr>
<p style="color:gray;font-size:11px;">Report Generated by <b>MySQL DBA Team</b></p>
</body>
</html>
EOF
} | /usr/sbin/sendmail -t

```
