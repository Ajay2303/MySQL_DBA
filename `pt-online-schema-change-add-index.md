## Online Schema Change using pt-online-schema-change

Percona Toolkit’s `pt-online-schema-change` is used to perform schema changes on large tables with minimal downtime.  
Below are sample commands for a **dry run** and an **actual run** when adding an index.

---

### 🔹 Dry Run Command

```bash
pt-online-schema-change \
  --alter "ADD INDEX index_name(column_name)" \
  --recursion-method=none \
  --no-check-alter \
  --critical-load Threads_running=2000 \
  --chunk-time=2 \
  --no-check-plan \
  --preserve-triggers \
  --alter-foreign-keys-method=auto \
  --set-vars "innodb_lock_wait_timeout=3000,sql_mode=''" \
  --host=hostname \
  --user=username \
  --ask-pass \
  --progress=time,30 \
  --print \
  --execute \
  D=database_name,t=tablename
```
### 🔹 Actual Run Command
```bash
pt-online-schema-change \
  --alter "ADD INDEX index_name(column_name)" \
  --recursion-method=none \
  --no-check-alter \
  --critical-load Threads_running=2000 \
  --chunk-time=2 \
  --no-check-plan \
  --preserve-triggers \
  --alter-foreign-keys-method=auto \
  --set-vars "innodb_lock_wait_timeout=3000,sql_mode=''" \
  --host=hostname \
  --user=username \
  --ask-pass \
  --progress=time,30 \
  --print \
  --execute \
  D=database_name,t=table_name
