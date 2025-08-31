# MySQL Table Growth Monitoring Script

This script monitors the **daily growth of MySQL tables** and sends an **HTML-formatted email report** highlighting the size differences between **today** and **yesterday**.  

---

## Features
- Tracks **table-level growth** in GB from `information_schema.tables`.
- Compares table size **day over day**.
- Includes **new tables** or tables that were removed (merged comparison).
- Highlights **growth values** with colors:
  - 🟢 **Green** → Low/No growth
  - 🟠 **Orange** → Moderate growth (>= 0.1 GB)
  - 🔴 **Red** → High growth (> 1 GB)
- Sends **HTML email** directly using `sendmail`.
- Maintains **baseline data** on first run.

---

## Files Used
The script stores temporary comparison files under:
- `table_size_today.txt` → Stores current day’s table sizes.  
- `table_size_yesterday.txt` → Stores previous day’s table sizes.  
- `table_size_merged.txt` → Merged list of tables (today + yesterday). 

## Script

```bash
#!/bin/bash

# ==============================================
# MySQL Table Growth Monitoring Script (Email Body)
# ==============================================

# Directories for temp files
BASE_DIR=""
TODAY_FILE="$BASE_DIR/table_size_today.txt"
YESTERDAY_FILE="$BASE_DIR/table_size_yesterday.txt"
MERGED_FILE="$BASE_DIR/table_size_merged.txt"

# Mail
MAIL_TO=""
MAIL_SUBJECT="Table Size Growth Report - $(date +%Y-%m-%d)"
MAIL_FROM=""

mkdir -p "$BASE_DIR"

# ==============================================
# Step 1: Get today's table sizes in GB (from .my.cnf)
# ==============================================
mysql -Nse "
SELECT
    table_schema,
    table_name,
    ROUND((data_length + index_length)/1024/1024/1024,6) AS total_gb
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema','performance_schema','mysql','sys')
ORDER BY table_schema, table_name;" > "$TODAY_FILE"

# ==============================================
# Step 2: Check if yesterday’s file exists
# ==============================================
if [[ ! -f "$YESTERDAY_FILE" ]]; then
    cp "$TODAY_FILE" "$YESTERDAY_FILE"
    echo "First run - baseline created. Report will start from tomorrow." | mailx -s "$MAIL_SUBJECT" -r "$MAIL_FROM" "$MAIL_TO"
    exit 0
fi

# ==============================================
# Step 3: Merge yesterday & today for complete table list
# ==============================================
awk '{print $1,$2}' "$TODAY_FILE" "$YESTERDAY_FILE" | sort -u > "$MERGED_FILE"

# ==============================================
# Step 4: Generate HTML content for email
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
<h2>MySQL Table Size Growth Report (GB)</h2>
<p>Generated on: $(date)</p>
<table>
<tr>
<th>Schema</th>
<th>Table</th>
<th>Yesterday (GB)</th>
<th>Today (GB)</th>
<th>Growth (GB)</th>
<th>Growth %</th>
</tr>"

while read schema table
do
    # Lookup sizes
    y_total=$(grep -w "$schema" "$YESTERDAY_FILE" | grep -w "$table" | awk '{print $3}')
    t_total=$(grep -w "$schema" "$TODAY_FILE" | grep -w "$table" | awk '{print $3}')

    # Default missing values to 0
    if [[ -z "$y_total" ]]; then y_total=0; fi
    if [[ -z "$t_total" ]]; then t_total=0; fi

    # Format numbers
    y_total=$(printf "%.6f" $y_total)
    t_total=$(printf "%.6f" $t_total)
    growth=$(echo "$t_total - $y_total" | bc)
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
    <td class='left'>$schema</td>
    <td class='left'>$table</td>
    <td>$(printf '%10s' $y_total)</td>
    <td>$(printf '%10s' $t_total)</td>
    <td class='$color_class'>$(printf '%10s' $growth)</td>
    <td class='$color_class'>$(printf '%10s' $growth_pct)</td>
    </tr>"
done < "$MERGED_FILE"

EMAIL_BODY+="</table>
<br>
<p style='font-size:12px;color:gray;'>Automated Report By MySQL DBA Team.</p>
</body>
</html>"

# ==============================================
# Step 5: Send email directly using sendmail
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
# Step 6: Rotate files (today -> yesterday)
# ==============================================
cp "$TODAY_FILE" "$YESTERDAY_FILE"
```

