#!/bin/bash
set -euo pipefail

# ==============================
# Configuration
# ==============================
DB_HOST="rl-prod-cluster-instance-1.c4tceyxqkrej.us-east-1.rds.amazonaws.com"
DB_USER="admin"
DB_PWD="A789v@er5itmar"
EMAIL="dccagent@geopits.com,mysqltechsupport@geopits.com"

# ==============================
# Output locations
# ==============================
DIR="/tmp/show_create_table_report"
DATE_TAG="$(date +%F_%H%M%S)"
OUT_JSON="${DIR}/rl_table_structure_${DATE_TAG}.json"
OUT_TSV="${DIR}/rl_table_structure_raw.tsv"
LOG_FILE="${DIR}/rl_table_structure_${DATE_TAG}.log"

mkdir -p "$DIR"
: > "$OUT_TSV"
: > "$LOG_FILE"

echo "Starting schema extraction..." | tee -a "$LOG_FILE"

# ==============================
# MySQL execution helper
# ==============================
mysql_exec() {
  MYSQL_PWD="$DB_PWD" mysql \
    -h "$DB_HOST" \
    -u "$DB_USER" \
    -N -B \
    --default-character-set=utf8mb4 \
    "$@"
}

# ==============================
# Exclude system databases
# ==============================
EXCLUDE_REGEX='^(information_schema|mysql|performance_schema|sys)$'

echo "Fetching database list..." | tee -a "$LOG_FILE"
DBS=$(mysql_exec -e "SHOW DATABASES;" | grep -Ev "$EXCLUDE_REGEX" || true)

if [[ -z "${DBS}" ]]; then
  echo "No non-system databases found." | tee -a "$LOG_FILE"
  exit 0
fi

# ==============================
# Collect schema data
# ==============================
while IFS= read -r DB_NAME; do
  [[ -z "$DB_NAME" ]] && continue

  echo "Processing database: $DB_NAME" | tee -a "$LOG_FILE"

  TABLES=$(mysql_exec -e "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = '$DB_NAME'
      AND table_type = 'BASE TABLE'
    ORDER BY table_name;
  " || true)

  [[ -z "$TABLES" ]] && continue

  while IFS= read -r TABLE_NAME; do
    [[ -z "$TABLE_NAME" ]] && continue

    ROW=$(mysql_exec -e "SHOW CREATE TABLE \`$DB_NAME\`.\`$TABLE_NAME\`;" || true)

    if [[ -n "$ROW" ]]; then
      SHOW_TABLE=$(printf '%s' "$ROW" | awk -F'\t' '{print $1}')
      CREATE_STMT=$(printf '%s' "$ROW" | cut -f2-)

      if [[ -n "$CREATE_STMT" ]]; then
        CREATE_B64=$(printf '%s' "$CREATE_STMT" | base64 | tr -d '\n')
        printf '%s\t%s\t%s\n' "$DB_NAME" "$SHOW_TABLE" "$CREATE_B64" >> "$OUT_TSV"
      fi
    fi

  done <<< "$TABLES"

done <<< "$DBS"

# ==============================
# Convert TSV to JSON
# Output format:
# [
#   {
#     "server": "...",
#     "databases": [
#       {
#         "database": "...",
#         "tables": [
#           {
#             "table": "...",
#             "create_statement": "..."
#           }
#         ]
#       }
#     ]
#   }
# ]
# ==============================
python3 - "$OUT_TSV" "$OUT_JSON" <<'PY'
import base64
import csv
import json
import socket
import sys
from collections import OrderedDict

tsv_file = sys.argv[1]
json_file = sys.argv[2]

server_name = socket.gethostname()

db_map = OrderedDict()

with open(tsv_file, newline="", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter="\t")
    for row in reader:
        if len(row) < 3:
            continue

        db_name = row[0]
        table_name = row[1]
        create_b64 = row[2]

        try:
            create_stmt = base64.b64decode(create_b64.encode("utf-8")).decode("utf-8")
        except Exception:
            create_stmt = ""

        if not create_stmt:
            continue

        if db_name not in db_map:
            db_map[db_name] = []

        db_map[db_name].append({
            "table": table_name,
            "create_statement": create_stmt
        })

output = [{
    "server": server_name,
    "databases": []
}]

for db_name, tables in db_map.items():
    output[0]["databases"].append({
        "database": db_name,
        "tables": tables
    })

with open(json_file, "w", encoding="utf-8") as f:
    json.dump(output, f, indent=2, ensure_ascii=False)

print(json_file)
PY

echo "JSON report created: $OUT_JSON" | tee -a "$LOG_FILE"

# ==============================
# Compress for email attachment
# ==============================
gzip -f "$OUT_JSON"
ATTACH_FILE="${OUT_JSON}.gz"

# ==============================
# Send email
# ==============================
MAIL_BODY="Hi Team,

Please find the attached Runloyal table structure JSON report.

Thanks,
Ajay S"

echo "$MAIL_BODY" | mutt \
  -s "Runloyal TABLE STRUCTURE JSON Report - $DATE_TAG" \
  -a "$ATTACH_FILE" -- $EMAIL

echo "Mail sent successfully: $ATTACH_FILE" | tee -a "$LOG_FILE"
