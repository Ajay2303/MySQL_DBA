# MySQL Charset and Collation Check Queries

## Database-Level Charset and Collation
```sql
SELECT 
    schema_name AS 'Database',
    default_character_set_name AS 'Charset',
    default_collation_name AS 'Collation'
FROM information_schema.schemata
WHERE schema_name NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
ORDER BY schema_name;
```
## Table-Level Charset and Collation
```sql
SELECT 
    t.table_schema AS 'Database',
    t.table_name AS 'Table',
    c.character_set_name AS 'Charset',
    t.table_collation AS 'Collation'
FROM information_schema.tables t
JOIN information_schema.collation_character_set_applicability c 
    ON t.table_collation = c.collation_name
WHERE t.table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
ORDER BY t.table_schema, t.table_name;
```
