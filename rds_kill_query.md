# mysql.rds_kill_query()

## Overview
`mysql.rds_kill_query()` is an Amazon RDS for MySQL stored procedure used to terminate a currently running query without disconnecting the associated session.

This procedure is useful when you need to stop a long-running query while keeping the user's session active.

---

## Syntax
```sql
CALL mysql.rds_kill_query(query_id);
