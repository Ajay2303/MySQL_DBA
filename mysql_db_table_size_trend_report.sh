#!/bin/bash
################################################################################
# MySQL DB & Table Size Trend Report
# Author: Ajay S
# Description:
#   Collects daily database & table sizes from MySQL, keeps last N days history,
#   generates an HTML trend report, and emails it.
#
# NOTE:
#   Credentials are placeholders. Use environment variables or a secrets manager
#   in production.
################################################################################

################################################################################
# CONFIGURATION
################################################################################
MYSQL_USER="<MYSQL_USER>"
MYSQL_PASS="<MYSQL_PASSWORD>"
MYSQL_HOST="<MYSQL_RDS_ENDPOINT>"

BASE_DIR="/home/ubuntu/dbsize"
HIST_DIR="$BASE_DIR/history"
REPORT_HTML="$BASE_DIR/daily_report.html"

DAYS=5
IGNORE_DBS="'mysql','information_schema','performance_schema','sys'"

MAIL_TO="team@example.com"
MAIL_CC="dba@example.com"
MAIL_SUBJECT="MySQL DB & Table Size Report | $(date '+%d-%m-%Y')"
MAIL_FROM="MySQL Reports <noreply@example.com>"

TODAY=$(date +"%Y-%m-%d")

mkdir -p "$HIST_DIR"

################################################################################
# SIZE FORMAT FUNCTION
################################################################################
format_size() {
    local s=$1
    if (( s >= 1024*1024*1024 )); then
        printf "%.2f GB" "$(echo "$s/1024/1024/1024" | bc -l)"
    elif (( s >= 1024*1024 )); then
        printf "%.2f MB" "$(echo "$s/1024/1024" | bc -l)"
    else
        printf "%.2f KB" "$(echo "$s/1024" | bc -l)"
    fi
}

################################################################################
# COLLECT TODAY DATA
################################################################################
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h"$MYSQL_HOST" -N <<EOF > "$HIST_DIR/$TODAY.db"
SELECT
    table_schema,
    table_name,
    SUM(data_length + index_length)
FROM information_schema.tables
WHERE table_schema NOT IN ($IGNORE_DBS)
GROUP BY table_schema, table_name;
EOF

################################################################################
# KEEP LAST N DAYS (SAFE CLEANUP)
################################################################################
FILE_COUNT=$(ls -1 "$HIST_DIR"/*.db 2>/dev/null | wc -l)
if (( FILE_COUNT > DAYS )); then
    ls -1 "$HIST_DIR"/*.db | sort | head -n -"$DAYS" | xargs -r rm -f
fi

################################################################################
# LOAD HISTORY FILES
################################################################################
FILES=($(ls -1 "$HIST_DIR"/*.db 2>/dev/null | sort))
[[ ${#FILES[@]} -eq 0 ]] && exit 0

DATES=()
for f in "${FILES[@]}"; do
    DATES+=("$(basename "$f" .db)")
done

################################################################################
# PRE-CALCULATIONS
################################################################################
TOTAL_DBS=$(awk '{print $1}' "${FILES[-1]}" | sort -u | wc -l)
TOTAL_TABLES=$(wc -l < "${FILES[-1]}")

TOP_DBS=$(awk '{db[$1]+=$3} END {for (d in db) print d, db[d]}' "${FILES[-1]}" \
          | sort -k2 -nr | head -10 | awk '{print $1}')

################################################################################
# HTML HEADER
################################################################################
cat > "$REPORT_HTML" <<EOF
<html>
<head>
<style>
body {
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 13px;
    background-color: #f0f9ff;
}
h2 { color: #075985; }
h3 { color: #0369a1; }
table {
    border-collapse: collapse;
    width: 100%;
    margin-bottom: 30px;
    background: #ffffff;
    box-shadow: 0 3px 10px rgba(2,132,199,0.15);
}
th, td {
    border: 1px solid #bae6fd;
    padding: 8px;
}
th {
    background: #e0f2fe;
    text-transform: uppercase;
}
.today {
    background: #bbf7d0;
    font-weight: bold;
}
.summary {
    margin-bottom: 20px;
    padding: 12px;
    background: #e0f2fe;
    border-left: 5px solid #0ea5e9;
}
.footer {
    font-size: 11px;
    text-align: center;
    color: #64748b;
}
</style>
</head>
<body>

<h2>MySQL DB and Table Size Trend Report</h2>

<div class="summary">
<b>Generated On:</b> $(date)<br>
<b>Total Databases:</b> $TOTAL_DBS<br>
<b>Total Tables:</b> $TOTAL_TABLES
</div>
EOF

################################################################################
# TABLE HEADER FUNCTION
################################################################################
print_header() {
    echo "<table><tr><th>$1</th>" >> "$REPORT_HTML"
    for d in "${DATES[@]}"; do
        echo "<th>$(date -d "$d" +"%d-%m-%y")</th>" >> "$REPORT_HTML"
    done
    echo "</tr>" >> "$REPORT_HTML"
}

################################################################################
# TOP 10 DATABASES
################################################################################
echo "<h3>Top 10 Databases</h3>" >> "$REPORT_HTML"
print_header "Database"

for db in $TOP_DBS; do
    echo "<tr><td><b>$db</b></td>" >> "$REPORT_HTML"
    for f in "${FILES[@]}"; do
        d=$(basename "$f" .db)
        size=$(awk -v db="$db" '$1==db {s+=$3} END{print s+0}' "$f")
        [[ "$d" == "$TODAY" ]] && c="today" || c=""
        echo "<td class='$c'>$(format_size "$size")</td>" >> "$REPORT_HTML"
    done
    echo "</tr>" >> "$REPORT_HTML"
done
echo "</table>" >> "$REPORT_HTML"

################################################################################
# FOOTER
################################################################################
cat >> "$REPORT_HTML" <<EOF
<div class="footer">
Automated Report by Ajay S – MySQL DBA
</div>
</body>
</html>
EOF

################################################################################
# SEND MAIL
################################################################################
(
echo "From: $MAIL_FROM"
echo "To: $MAIL_TO"
echo "Cc: $MAIL_CC"
echo "Subject: $MAIL_SUBJECT"
echo "MIME-Version: 1.0"
echo "Content-Type: text/html"
cat "$REPORT_HTML"
) | sendmail -t
