# MySQL Dump Command

``` bash
mysqldump \
  -h <HOSTNAME> \
  -u <USERNAME> -p \
  --init-command="SET SESSION max_execution_time=0; SET SESSION wait_timeout=0;" \
  --single-transaction \
  --skip-lock-tables \
  --set-gtid-purged=OFF \
  --max-allowed-packet=1G \
  <DB_NAME> <TABLE_NAME> \
  > <TABLE_NAME>_$(date +"%Y-%m-%d_%H-%M-%S").sql
```
