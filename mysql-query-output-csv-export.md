# MySQL Query Output to CSV

## 1. Export Query output to CSV

Use the following command to export a MySQL Query into a CSV file with column headers.

```bash
mysql -h <MYSQL_HOST> -P <MYSQL_PORT> -u <MYSQL_USER> -p <DATABASE_NAME> \
--batch --raw -e "<Query>;" | tr '\t' ',' > <OUTPUT_FILE>.csv
