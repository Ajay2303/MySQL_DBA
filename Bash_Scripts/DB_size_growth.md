# 📊 MySQL Database Growth Monitoring Script

This script monitors the daily growth of MySQL databases and sends an HTML-formatted email report highlighting the size differences between **today** and **yesterday**.  

---

## 🚀 Features
- Collects database sizes in **GB** from `information_schema.tables`.
- Compares today’s size with yesterday’s size.
- Highlights **growth values** with colors:
  - 🟢 **Green** → Low/No growth
  - 🟠 **Orange** → Moderate growth (>= 0.1 GB)
  - 🔴 **Red** → High growth (> 1 GB)
- Sends **HTML email** directly via `sendmail`.
- Automatically maintains a **baseline file** on the first run.

---

## 📂 Files Used
- `db_size_today.txt` → Stores current day’s DB sizes.  
- `db_size_yesterday.txt` → Stores previous day’s DB sizes.  

## 📝 Script

```bash
#!/bin/bash

# ==============================================
# MySQL Database Growth Monitoring Script
# ==============================================

# Directories for temp files
BASE_DIR="/docker/dbamonitoring/db_growth"
TODAY_FILE="$BASE_DIR/db_size_today.txt"
YESTERDAY_FILE="$BASE_DIR/db_size_yesterday.txt"

# Mail
MAIL_TO="mysqltechsupport@geopits.com,udhayanan.l@credopay.com,somasundaram.s@credopay.com,bhagyasri.m@credopay.com,customersupport1@credopay.com"
MAIL_SUBJECT="Database Size Growth Report - $(date +%Y-%m-%d)"
MAIL_FROM="CredoPay MySQL <mysqlalert1@gmail.com>"

mkdir -p "$BASE_DIR"

# ==============================================
# Step 1: Get today's database sizes in GB
# ==============================================
mysql -Nse "
SELECT
    table_schema,
    ROUND(SUM(data_length + index_length)/1024/1024/1024,6) AS total_gb
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema','performance_schema','mysql','sys')
GROUP BY table_schema
ORDER BY table_schema;" > "$TODAY_FILE"

# ==============================================
# Step 2: Check if yesterday’s file exists
# ==============================================
if [[ ! -f "$YESTERDAY_FILE" ]]; then
    cp "$TODAY_FILE" "$YESTERDAY_FILE"
    echo "First run - baseline created. Report will start from tomorrow." | mailx -s "$MAIL_SUBJECT" -r "$MAIL_FROM" "$MAIL_TO"
    exit 0
fi

# ==============================================
# Step 3: Generate HTML content for email
# ==============================================
EMAIL_BODY="<html>
<head>
<style>
body { font-family: Arial, sans-serif; font-size: 14px; }
h2 { color: #2E86C1; }
table { border-collapse: collapse; width: 100%; table-layout: fixed; }
th, td { border: 1px solid #ccc; padding: 6px; text-align: right; font-family: monospace; }
th { background-color: #34495E; color: white; text-align: center; }
tr:nth-child(even) { background-color: #f2f2f2; }
tr:nth-child(odd) { background-color: #ffffff; }
td.left { text-align: left; }
td.green { color: green; font-weight: bold; }
td.orange { color: orange; font-weight: bold; }
td.red { color: red; font-weight: bold; }
</style>
</head>
<body>
<h2>MySQL Database Size Growth Report (GB)</h2>
<p>Generated on: $(date)</p>
<table>
<tr>
<th>Database</th>
<th>Yesterday (GB)</th>
<th>Today (GB)</th>
<th>Growth (GB)</th>
<th>Growth %</th>
</tr>"

while read db total_gb
do
    y_total=$(grep -w "$db" "$YESTERDAY_FILE" | awk '{print $2}')
    if [[ -z "$y_total" ]]; then y_total=0; fi

    total_gb=$(printf "%.6f" $total_gb)
    y_total=$(printf "%.6f" $y_total)
    growth=$(echo "$total_gb - $y_total" | bc)
    growth=$(printf "%.6f" $growth)

    if (( $(echo "$y_total > 0" | bc -l) )); then
        growth_pct=$(echo "scale=4; ($growth/$y_total)*100" | bc)
    else
        growth_pct="N/A"
    fi

    # Color-coding growth
    if (( $(echo "$growth > 1" | bc -l) )); then
        color_class="red"
    elif (( $(echo "$growth >= 0.1" | bc -l) )); then
        color_class="orange"
    else
        color_class="green"
    fi

    EMAIL_BODY+="<tr>
    <td class='left'>$db</td>
    <td>$(printf '%10s' $y_total)</td>
    <td>$(printf '%10s' $total_gb)</td>
    <td class='$color_class'>$(printf '%10s' $growth)</td>
    <td class='$color_class'>$(printf '%10s' $growth_pct)</td>
    </tr>"
done < "$TODAY_FILE"

EMAIL_BODY+="</table>
<br>
<p style='font-size:12px;color:gray;'>Automated Report By MySQL DBA Team.</p>
</body>
</html>"

# ==============================================
# Step 4: Send email directly using sendmail
# ==============================================
(
echo "From: $MAIL_FROM"
echo "To: $MAIL_TO"
echo "Subject: $MAIL_SUBJECT"
echo "MIME-Version: 1.0"
echo "Content-Type: text/html"
echo
echo "$EMAIL_BODY"
) | sendmail -t

# ==============================================
# Step 5: Rotate files (today -> yesterday)
# ==============================================
cp "$TODAY_FILE" "$YESTERDAY_FILE"
```
