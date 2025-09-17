## ALTER TABLE … ADD INDEX with ALGORITHM and LOCK

The following query is used to add a new index on a column with minimal downtime:

```sql
ALTER TABLE table_name 
ALGORITHM=INPLACE, LOCK=NONE, 
ADD INDEX index_name(column_name);
