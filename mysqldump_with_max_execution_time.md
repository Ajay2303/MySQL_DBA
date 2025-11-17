# MySQL Dump Command

``` bash
mysqldump \
  -h prod-cde-mysql-v8.cfy99p6milqu.ap-south-1.rds.amazonaws.com \
  -u rapyder.vimal.v -p \
  --init-command="SET SESSION max_execution_time=0, SESSION wait_timeout=0" \
  --single-transaction \
  --skip-lock-tables \
  --set-gtid-purged=OFF \
  --max-allowed-packet=1G \
  oneassist oa_customer_tmp_hst \
  > oa_customer_tmp_hst_$(date +"%Y-%m-%d_%H-%M-%S").sql
```
