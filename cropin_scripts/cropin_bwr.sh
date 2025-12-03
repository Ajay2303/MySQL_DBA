#!/bin/bash

MYSQL_USER="jana"
MYSQL_HOST="productionmysql-new.cewqmdlrwgkt.ap-southeast-1.rds.amazonaws.com"
MYSQL_PASSWORD="J@n@876#"
CLIENT_NAME="Cropin"
CLIENT=cropin
DATABASE_TYPE="MYSQL"
MYSQL_PORT="3306"

TO_EMAIL="dccagent@geopits.com,rohith@geopits.com,ajay@geopits.com"
#TO_EMAIL="rohith@geopits.com"
SUBJECT="REPORT_DATA/MySQL/$CLIENT"
#SUBJECT="$CLIENT_NAME - MySQL Database Health Check Report (XML)"
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="/home/mysqladmin/cropin/report/${CLIENT// /_}_MySQL_Health_Report_${CURRENT_DATE//}.xml"

DBInstance="productionmysql-new"
#INSTANCETYPE=$(aws rds describe-db-instances --db-instance-identifier "$DBInstance" --query "DBInstances[0].DBInstanceClass" --output text)
DB_VERSION=$(mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "SELECT VERSION();" | awk '{print $1}')
DATABASE_SIZE=$(mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "SELECT ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2) FROM information_schema.tables WHERE TABLE_SCHEMA NOT IN ('information_schema','performance_schema','sys','mysql');")
CPU=8
RAM=64GB

# Start XML
{
  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  echo "<ReportData"
  echo "  client=\"$CLIENT\""
  echo "  generatedOn=\"$(date +%Y-%m-%dT%H:%M:%S%z)\""
  echo "  database=\"$DATABASE_TYPE\""
  echo "  instanceName=\"$MYSQL_HOST\">"
#  echo "<MySQLHealthReport client=\"$CLIENT_NAME\" generatedOn=\"$(date)\">"
} > "$OUTPUT_FILE"

# DB server details:

{
  echo "<Item name=\"MySQL Server Info\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"MySQL Server Info\" />"
  echo "    <meta key=\"description\" value=\"Details of the MySQL instance such as the Hostname, CPU, memory, storage, database version and database size.\" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"Property\" type=\"string\" />"
  echo "      <value name=\"Value\" type=\"string\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"
  echo "    <row Property=\"Host\" Value=\"$MYSQL_HOST\" />"
  echo "    <row Property=\"RAM\" Value=\"$RAM\" />"
  echo "    <row Property=\"vCPU\" Value=\"$CPU\" />"
  echo "    <row Property=\"Version\" Value=\"$DB_VERSION\" />"
  echo "    <row Property=\"Database Size\" Value=\"$DATABASE_SIZE\" />"
  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

# Database Size Per DB
{
  echo "<Item name=\"Database Size\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Database Size\" />"
  echo "    <meta key=\"description\" value=\"Displays the size of each database (data + indexes) in MB/GB. Helps in storage planning, identifying fast-growing databases, and managing space efficiently.\" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"Database Name\" type=\"string\" />"
  echo "      <value name=\"Size GB\" type=\"float\" />"
  echo "      <value name=\"Size MB\" type=\"float\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"
  mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "
    SELECT TABLE_SCHEMA,
           ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2),
           ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 , 2)
    FROM information_schema.tables
    WHERE TABLE_SCHEMA NOT IN ('information_schema','performance_schema','sys','mysql')
    GROUP BY TABLE_SCHEMA;" | while read -r db gb mb; do
      echo "    <row Database__x20__Name =\"$db\" Size__x20__GB =\"$gb\" Size__x20__MB =\"$mb\" />"
  done
  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

# Table Count by Engine
{
  echo "<Item name=\"Table Counts By Engine\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Table Counts By Engine\" />"
  echo "    <meta key=\"description\" value=\"Shows how many tables exist under each storage engine (e.g., InnoDB, MyISAM). Useful for performance tuning and understanding data distribution by engine type. \" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"Database Name\" type=\"string\" />"
  echo "      <value name=\"Engine\" type=\"string\" />"
  echo "      <value name=\"Count\" type=\"int\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"
  mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "
    SELECT TABLE_SCHEMA, ENGINE, COUNT(*)
    FROM information_schema.tables
    WHERE TABLE_TYPE='BASE TABLE' AND TABLE_SCHEMA NOT IN ('information_schema','performance_schema','sys','mysql')
    GROUP BY TABLE_SCHEMA, ENGINE;" | while read -r db engine count; do
    echo "    <row Database__x20__Name =\"$db\" Engine =\"$engine\" Count=\"$count\" />"
  done
  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

# Large Tables (>1M rows)
{
  echo "<Item name=\"Large Tables Over 1 Million Rows\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Large Tables Over 1 Million Rows\" />"
  echo "    <meta key=\"description\" value=\"Lists tables that contain more than one million rows. Helps identify large datasets that may affect query performance or require archiving or partitioning. \" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"Database Name\" type=\"string\" />"
  echo "      <value name=\"Table Name\" type=\"string\" />"
  echo "      <value name=\"Row Count\" type=\"int\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"

  # Run query and store result in variable
  large_tables=$(mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "
    SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_ROWS
    FROM information_schema.tables
    WHERE TABLE_ROWS > 1000000 AND TABLE_SCHEMA NOT IN ('information_schema','performance_schema','sys','mysql')
    ORDER BY TABLE_ROWS DESC;")

  if [[ -z "$large_tables" ]]; then
    echo "    No table were found with more than 1 million rows."
  else
    echo "$large_tables" | while read -r db table rows; do
      echo "    <row Database__x20__Name=\"$db\" Table__x20__Name=\"$table\" Row__x20__Count=\"$rows\" />"
    done
  fi

  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

# Top 10 Big Tables by Data Size
{
  echo "<Item name=\"Top 10 big tables based on size\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Top 10 big tables based on size\" />"
  echo "    <meta key=\"description\" value=\"Lists the top ten largest tables in terms of physical storage. Helps prioritize optimization efforts, manage disk space, and identify potential storage issues.\" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"Database Name\" type=\"string\" />"
  echo "      <value name=\"Table Name\" type=\"string\" />"
  echo "      <value name=\"Size GB\" type=\"float\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"
  mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "
    SELECT TABLE_SCHEMA, TABLE_NAME, ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 / 1024, 2) AS size_gb
    FROM information_schema.tables
    WHERE TABLE_SCHEMA NOT IN ('information_schema','performance_schema','sys','mysql')
    ORDER BY size_gb DESC
    LIMIT 10;" | while read -r db table size; do
    echo "    <row Database__x20__Name=\"$db\" Table__x20__Name =\"$table\" Size__x20__GB=\"$size\" />"
  done
  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

# Top 10 Fragmented Tables with Size and Percentage
{
  echo "<Item name=\"Top 10 Fragmented Tables\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Top 10 Fragmented Tables\" />"
  echo "    <meta key=\"description\" value=\"Shows tables with the highest level of fragmentation. Fragmented tables can slow down queries and increase storage use, so identifying them helps in maintenance (e.g., using OPTIMIZE TABLE).\" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  # echo "      <value name=\"Database Name\" type=\"string\" />"
  echo "      <value name=\"Table Name\" type=\"string\" />"
  echo "      <value name=\"Table Size GB\" type=\"float\" />"
  echo "      <value name=\"Data Free GB\" type=\"float\" />"
  echo "      <value name=\"Data Free Pct\" type=\"string\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"
  mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "
    SELECT CONCAT(table_schema, '.', table_name) as 'Table',CONCAT(ROUND((data_length +index_length) / ( 1024 * 1024 * 1024 ), 3), 'G') AS 'Table Size' ,CONCAT(ROUND(( data_free /1024 / 1024/1024),2), 'GB') AS 'Data Free',CONCAT('(',IF(data_free< ( data_length +index_length ) ,CONCAT(round(data_free/(data_length+index_length)*100,2),'%'),'100%'),')') AS'Data Free Pct' FROM information_schema.TABLES where table_schema not in ('mysql','performance_schema','sys','test','mydbops','information_schema') ORDER BY ROUND(data_free / 1024 / 1024/1024,2) desc LIMIT 10;" | while read -r table size_gb free_gb percent; do
    echo "    <row table=\"$table\" tableSizeGB=\"$size_gb\" fragmentationGB=\"$free_gb\" fragmentationPercent=\"$percent\" />"
  done
  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

# Tables Without Primary Key
{
  echo "<Item name=\"Tables Without Primary Key\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Tables Without Primary Key\" />"
  echo "    <meta key=\"description\" value=\"List the table with no primary key. Help to indentify the potential table that can cause the performance issue.\" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"Database Name\" type=\"string\" />"
  echo "      <value name=\"Table Name\" type=\"string\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"

  # Store the query result in a variable
  no_pk_tables=$(mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "
    SELECT DISTINCT t.TABLE_SCHEMA, t.TABLE_NAME
    FROM information_schema.tables t
    LEFT JOIN information_schema.key_column_usage k
      ON t.TABLE_SCHEMA = k.TABLE_SCHEMA
      AND t.TABLE_NAME = k.TABLE_NAME
      AND k.CONSTRAINT_NAME = 'PRIMARY'
    WHERE t.TABLE_TYPE = 'BASE TABLE'
      AND t.TABLE_SCHEMA NOT IN ('information_schema','performance_schema','sys','mysql')
      AND k.CONSTRAINT_NAME IS NULL
    ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME;")

  # Check and output accordingly
  if [[ -z "$no_pk_tables" ]]; then
    echo "    There is no table without primary key."
  else
    echo "$no_pk_tables" | while read -r db table; do
      echo "    <row database=\"$db\" table=\"$table\" />"
    done
  fi

  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"


# Zero Record Tables
{
  echo "<Item name=\"Zero Record Tables\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Zero Record Tables\" />"
  echo "    <meta key=\"description\" value=\"Lists the tables with no records or data. Helps to find the unused tables.\" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"Database Name\" type=\"string\" />"
  echo "      <value name=\"Table Name\" type=\"string\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"

  # Run and store the result in a variable
  zero_tables=$(mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "
    SELECT TABLE_SCHEMA, TABLE_NAME
    FROM information_schema.tables
    WHERE TABLE_ROWS = 0
      AND TABLE_SCHEMA NOT IN ('information_schema','performance_schema','sys','mysql')
    ORDER BY TABLE_SCHEMA, TABLE_NAME;")

  # Check and format
  if [[ -z "$zero_tables" ]]; then
    echo "    There is no table with zero records."
  else
    echo "$zero_tables" | while read -r db table; do
      echo "    <row database=\"$db\" table=\"$table\" />"
    done
  fi

  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"


# User Analysis
{
  echo "<Item name=\"User Analysis\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"User Analysis\" />"
  echo "    <meta key=\"description\" value=\"Lists all MySQL user accounts along with their current status (active, locked, expired). Useful for security reviews and identifying unused or risky accounts.\" />"
  echo "    <meta key=\"type\" value=\"table\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"Username\" type=\"string\" />"
  echo "      <value name=\"Host\" type=\"string\" />"
  echo "      <value name=\"Password Expired\" type=\"string\" />"
  echo "      <value name=\"Password Last Changed\" type=\"string\" />"
  echo "      <value name=\"Account Locked\" type=\"string\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data>"
  mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -p"$MYSQL_PASSWORD" -ss -e "
    SELECT 
      user,
      host,
      password_expired,
      IFNULL(DATE_FORMAT(password_last_changed, '%Y-%m-%d %H:%i:%s'), 'NULL'),
      account_locked
    FROM 
      mysql.user;" | while IFS=$'\t' read -r username host expired changed locked; do
    echo "    <row username=\"$username\" host=\"$host\" passwordExpired=\"$expired\" passwordLastChanged=\"$changed\" accountLocked=\"$locked\" />"
  done
  echo "  </data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

# # Server Statistics and DML Operations.

# result=$(mysql -u $MYSQL_USER -p$MYSQL_PASS -h $MYSQL_HOST -e '\s')

# uptime=$(echo "$result" | grep -i "Uptime" | awk -F'Uptime:' '{print $2}' | awk -F'Queries' '{print $1}' | xargs)
# qps=$(echo "$result" | grep -i "Queries per second avg" | awk -F':' '{print $2}' | xargs)

# Fetch `\s` summary from MySQL (status output)
status_output=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h"$MYSQL_HOST" -e '\s')

# Uptime
uptime=$(echo "$status_output" | grep -i "Uptime" | awk -F'Uptime:' '{print $2}' | awk -F'Queries' '{print $1}' | xargs)

# QPS (Queries per second average)
qps=$(echo "$status_output" | grep -i "Queries per second avg" | awk -F':' '{print $2}' | xargs)

# Aborted Connections: Total & Percentage
read total_connections aborted_connections aborted_pct <<< $(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h"$MYSQL_HOST" -sse "
SELECT total_connections, aborted_connections,
       ROUND((aborted_connections / total_connections) * 100, 4)
FROM (
    SELECT 
      (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Connections') AS total_connections,
      (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Aborted_connects') AS aborted_connections
) AS conn_stats;
")

# Joins performed without indexes
select_full_join=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h"$MYSQL_HOST" -sse "
SELECT VARIABLE_VALUE 
FROM performance_schema.global_status 
WHERE VARIABLE_NAME = 'Select_full_join';
")

# XML code for server statistics and DML operations
{
  echo "<Item name=\"Server Uptime\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Server Uptime\" />"
  echo "    <meta key=\"description\" value=\"Displays how long the MySQL server has been running without a restart. Useful to assess stability, detect crashes, and plan maintenance.\" />"
  echo "    <meta key=\"type\" value=\"text\" />"
  echo "  </renderConfig>"
  echo "  <data>Uptime: $uptime</data>"
  echo "</Item>"

  echo "<Item name=\"Queries Per Second (QPS)\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Queries Per Second (QPS)\" />"
  echo "    <meta key=\"description\" value=\"Shows the number of queries executed per second. A key performance indicator for monitoring server workload and detecting spikes in traffic.\" />"
  echo "    <meta key=\"type\" value=\"text\" />"
  echo "  </renderConfig>"
  echo "  <data>Queries per second avg: $qps</data>"
  echo "</Item>"

  echo "<Item name=\"Aborted Connections\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Aborted Connections\" />"
  echo "    <meta key=\"description\" value=\"Tracks failed or terminated client connections. High numbers can indicate network issues, authentication failures, or misconfigured applications.\" />"
  echo "    <meta key=\"type\" value=\"text\" />"
  echo "  </renderConfig>"
  echo "  <data>Aborted connections: ${aborted_pct}% ($aborted_connections/$total_connections)</data>"
  echo "</Item>"

  echo "<Item name=\"Joins Performed Without Indexes\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Joins Without Indexes\" />"
  echo "    <meta key=\"description\" value=\"Identifies queries performing table joins without appropriate indexing. These queries can be slow and resource-intensive, making this useful for performance tuning.\" />"
  echo "    <meta key=\"type\" value=\"text\" />"
  echo "  </renderConfig>"
  echo "  <data>Joins performed without indexes (Select_full_join): $select_full_join</data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

# Get full InnoDB status
innodb_status=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h"$MYSQL_HOST" -e "SHOW ENGINE INNODB STATUS\G")

# To extract only the foreign key errors.
foreign_key_block=$(echo "$innodb_status" | awk '/LATEST FOREIGN KEY ERROR/,/PHYSICAL RECORD:/ {print}' | xargs -0 echo)

# To extract the latest deadlock.
deadlock_block=$(echo "$innodb_status" | awk '/LATEST DETECTED DEADLOCK/,/WE ROLL BACK/ {print}' | xargs -0 echo)

# To extract the row operations.
row_ops_block=$(echo "$innodb_status" | awk '/ROW OPERATIONS/,/^$/ {print}' | xargs -0 echo)

# Foreign Key Error.
{
  echo "<Item name=\"Foreign Key Errors\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Foreign Key Error\" />"
  echo "    <meta key=\"description\" value=\"A foreign key error is typically means there's a mismatch or violation in the relationship between two tables like datatype mismatch, missing indexes, or referencing non-existent rows. \" />"
  echo "    <meta key=\"type\" value=\"text\" />"
  echo "  </renderConfig>"
  if [[ -n "$foreign_key_block" ]]; then
    echo "  <data><![CDATA[$foreign_key_block]]></data>"
  else
    echo "  <data>No foreign key constraint error found.</data>"
  fi
  echo "</Item>"

# Deadlocks.

  echo "<Item name=\"Deadlocks\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Deadlock Information\" />"
  echo "    <meta key=\"description\" value=\"A deadlock occurs when two or more transactions wait for each other to release locks, causing a cycle with no resolution. MySQL automatically detects and rolls back one to break the deadlock.\" />"
  echo "    <meta key=\"type\" value=\"text\" />"
  echo "  </renderConfig>"
  if [[ -n "$deadlock_block" ]]; then
    echo "  <data><![CDATA[$deadlock_block]]></data>"
  else
    echo "  <data>No deadlock found.</data>"
  fi
  echo "</Item>"

# Row Operations.

  echo "<Item name=\"Row Operations\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"InnoDB Row Operations\" />"
  echo "    <meta key=\"description\" value=\"Row operations in MySQL InnoDB refer to the actions performed on table rows like inserts, updates, deletes, and reads. They help monitor how the database is interacting with data at the row level for performance tuning.\" />"
  echo "    <meta key=\"type\" value=\"text\" />"
  echo "  </renderConfig>"
  if [[ -n "$row_ops_block" ]]; then
    echo "  <data><![CDATA[$row_ops_block]]></data>"
  else
    echo "  <data>No row operation block found.</data>"
  fi
  echo "</Item>"
} >> "$OUTPUT_FILE"

# Duplicate indexes.

DUPLICATE=$(pt-duplicate-key-checker --host="$MYSQL_HOST" --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" --port="$MYSQL_PORT")

# Checks if empty
if [[ -z "$DUPLICATE" ]]; then
  DUPLICATE="No duplicate indexes found."
fi

{
  echo "<Item name=\"Duplicate Indexes\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"Duplicate Index Checker\" />"
  echo "    <meta key=\"description\" value=\"Duplicate indexes in MySQL are multiple indexes on the same column or set of columns in the same order. They waste storage and slow down write performance without improving query speed.\" />"
  echo "    <meta key=\"type\" value=\"text\" />"
  echo "  </renderConfig>"
  echo "  <data><![CDATA[$DUPLICATE]]></data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"


CPUDATA=$(aws cloudwatch get-metric-data \
    --region ap-southeast-1 \
    --start-time "$(date -u -d '-15 days' +'%Y-%m-%dT%H:%M:%SZ')" \
    --end-time "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --metric-data-queries "[
      {
        \"Id\": \"cpu\",
        \"MetricStat\": {
          \"Metric\": {
            \"Namespace\": \"AWS/RDS\",
            \"MetricName\": \"CPUUtilization\",
            \"Dimensions\": [
              {
                \"Name\": \"DBInstanceIdentifier\",
                \"Value\": \"${DBInstance}\"
              }
            ]
          },
          \"Period\": 300,
          \"Stat\": \"Average\"
        },
        \"ReturnData\": true
      }
    ]" --output json | jq '{
      timestamp: .MetricDataResults[0].Timestamps,
      value: .MetricDataResults[0].Values
    }' )

{
  echo "<Item name=\"CPUUtilization\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"CPU Utilization\" />"
  echo "    <meta key=\"description\" value=\"Last 15 days CPU utilization from AWS CloudWatch.\" />"
  echo "    <meta key=\"type\" value=\"chart\" />"
  echo "    <meta key=\"graph_type\" value=\"series\" />"
  echo "    <meta key=\"data_parser\" value=\"aws_cli\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"timestamp\" type=\"datetime\" index=\"true\"/>"
  echo "      <value name=\"value\" type=\"number\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data><![CDATA[$CPUDATA]]></data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

#TODO: FreeableMemory

MEMDATA=$(aws cloudwatch get-metric-data \
    --region ap-southeast-1 \
    --start-time "$(date -u -d '-15 days' +'%Y-%m-%dT%H:%M:%SZ')" \
    --end-time "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --metric-data-queries "[
      {
        \"Id\": \"memory\",
        \"MetricStat\": {
          \"Metric\": {
            \"Namespace\": \"AWS/RDS\",
            \"MetricName\": \"FreeableMemory\",
            \"Dimensions\": [
              {
                \"Name\": \"DBInstanceIdentifier\",
                \"Value\": \"${DBInstance}\"
              }
            ]
          },
          \"Period\": 300,
          \"Stat\": \"Average\"
        },
        \"ReturnData\": true
      }
    ]" --output json | jq '{
      timestamp: .MetricDataResults[0].Timestamps,
      value: .MetricDataResults[0].Values
    }' )

{
  echo "<Item name=\"FreeableMemory\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"FreeableMemory\" />"
  echo "    <meta key=\"description\" value=\"Last 15 days FreeableMemory from AWS CloudWatch.\" />"
  echo "    <meta key=\"type\" value=\"chart\" />"
  echo "    <meta key=\"graph_type\" value=\"series\" />"
  echo "    <meta key=\"data_parser\" value=\"aws_cli\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"timestamp\" type=\"datetime\" index=\"true\"/>"
  echo "      <value name=\"value\" type=\"number\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data><![CDATA[$MEMDATA]]></data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

#TODO: FreeStorageSpace

STRDATA=$(aws cloudwatch get-metric-data \
    --region ap-southeast-1 \
    --start-time "$(date -u -d '-15 days' +'%Y-%m-%dT%H:%M:%SZ')" \
    --end-time "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --metric-data-queries "[
      {
        \"Id\": \"storage\",
        \"MetricStat\": {
          \"Metric\": {
            \"Namespace\": \"AWS/RDS\",
            \"MetricName\": \"FreeStorageSpace\",
            \"Dimensions\": [
              {
                \"Name\": \"DBInstanceIdentifier\",
                \"Value\": \"${DBInstance}\"
              }
            ]
          },
          \"Period\": 300,
          \"Stat\": \"Average\"
        },
        \"ReturnData\": true
      }
    ]" --output json | jq '{
      timestamp: .MetricDataResults[0].Timestamps,
      value: .MetricDataResults[0].Values
    }' )

{
  echo "<Item name=\"FreeStorageSpace\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"FreeStorageSpace\" />"
  echo "    <meta key=\"description\" value=\"Last 15 days FreeStorageSpace from AWS CloudWatch.\" />"
  echo "    <meta key=\"type\" value=\"chart\" />"
  echo "    <meta key=\"graph_type\" value=\"series\" />"
  echo "    <meta key=\"data_parser\" value=\"aws_cli\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"timestamp\" type=\"datetime\" index=\"true\"/>"
  echo "      <value name=\"value\" type=\"number\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data><![CDATA[$STRDATA]]></data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"

#TODO: DATABASE CONNECTIONS

DBCONDATA=$(aws cloudwatch get-metric-data \
    --region ap-southeast-1 \
    --start-time "$(date -u -d '-15 days' +'%Y-%m-%dT%H:%M:%SZ')" \
    --end-time "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --metric-data-queries "[
      {
        \"Id\": \"dbconnections\",
        \"MetricStat\": {
          \"Metric\": {
            \"Namespace\": \"AWS/RDS\",
            \"MetricName\": \"DatabaseConnections\",
            \"Dimensions\": [
              {
                \"Name\": \"DBInstanceIdentifier\",
                \"Value\": \"${DBInstance}\"
              }
            ]
          },
          \"Period\": 300,
          \"Stat\": \"Average\"
        },
        \"ReturnData\": true
      }
    ]" --output json | jq '{
      timestamp: .MetricDataResults[0].Timestamps,
      value: .MetricDataResults[0].Values
    }' )

{
  echo "<Item name=\"DatabaseConnections\">"
  echo "  <renderConfig>"
  echo "    <meta key=\"title\" value=\"DatabaseConnections\" />"
  echo "    <meta key=\"description\" value=\"Last 15 days DatabaseConnections from AWS CloudWatch.\" />"
  echo "    <meta key=\"type\" value=\"chart\" />"
  echo "    <meta key=\"graph_type\" value=\"series\" />"
  echo "    <meta key=\"data_parser\" value=\"aws_cli\" />"
  echo "    <meta key=\"columns\" multiple=\"true\">"
  echo "      <value name=\"timestamp\" type=\"datetime\" index=\"true\"/>"
  echo "      <value name=\"value\" type=\"number\" />"
  echo "    </meta>"
  echo "  </renderConfig>"
  echo "  <data><![CDATA[$DBCONDATA]]></data>"
  echo "</Item>"
} >> "$OUTPUT_FILE"


# Closing the XML tag.

echo "  </ReportData>"  >> "$OUTPUT_FILE"

# Email Report
# Send report via email
echo "Please find attached the XML report." | mailx -s "$SUBJECT" -A "$OUTPUT_FILE" "$TO_EMAIL"
echo "XML Report sent to $TO_EMAIL"



