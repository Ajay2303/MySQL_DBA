## MySQL PAGER Command

The `pager` command in the MySQL client lets you **pipe query output** through external programs like `grep`, `less`, `tee`, `awk`, etc.  
This is extremely useful for DBAs when handling **large outputs**, filtering results or saving query logs.

## 1. Exclude Sleep Connections
```sql
pager grep -v Sleep;

SHOW FULL PROCESSLIST;

-- Shows all connections except those in "Sleep" state.
```

## 2. Send Output to Standard Console
```sql
pager stdout;

-- Resets output to normal console immediately.
```

## 3. Checksum Query Output
```sql
pager md5sum;

SELECT * FROM table_name;

-- Generates an MD5 checksum of results.
```

## 4. View Results Page by Page
```sql
pager less -S;

-- Scroll results page by page (-S prevents line wrapping).
```

## 5. View Results One Screen at a Time
```sql
pager more;

-- Simpler pager, space to scroll, q to quit.
```

## 6. Save Query Output to a File
```sql
pager cat > /tmp/output.txt;

SELECT * FROM mysql.user;

-- Saves results into /tmp/output.txt.
```

## 7. Save and Show Results Together
```sql
pager tee /tmp/query_output.log;

SELECT NOW();

-- Displays results and saves them to a file.
```

## 8. Filter Output with grep
```sql
pager grep root;

SELECT user, host FROM mysql.user;

-- Shows only rows containing "root".
```

## 9. Highlight Matches with grep
```sql
pager grep --color -i lock;

SHOW FULL PROCESSLIST;

-- Highlights "lock" in output (-i = case-insensitive).
```

## 10. Remove Blank Lines with sed
```sql
pager sed '/^$/d';

SHOW CREATE TABLE mysql.user;

-- Removes empty lines from output.
```

## 11. Extract Specific Columns with awk
```sql
pager awk '{print $1, $2}';

SELECT user, host, plugin FROM mysql.user;

-- Prints only the first and second columns.
```

## 12. Limit Output Width with cut
```sql
pager cut -c 1-50;

SELECT * FROM information_schema.tables;

-- Shows only the first 50 characters per line.
```

## 13. Combine Multiple Pager Commands
```sql
pager grep "ERROR" | tee /tmp/errors.log | less -S;

SHOW ENGINE INNODB STATUS\G

-- Filters "ERROR", saves to file, and shows in pager.
```

## 14. Disable Pager
```sql
nopager;

-- Restores normal output mode.
```

## 15. Sort Results
```sql
pager sort;

SELECT user, host FROM mysql.user;

-- Sorts query output alphabetically.
```

## 16. Count Output Lines
```sql
pager wc -l;

SELECT * FROM information_schema.tables;

-- Shows how many rows were printed.
```

## 17. Reverse Output
```sql
pager tac;

SELECT user, host FROM mysql.user;

-- Displays results in reverse order.
```

## 18. Compress Output on the Fly
```sql
pager gzip > /tmp/output.gz;

SELECT * FROM big_table;

-- Saves results directly as a compressed .gz file.
```

## 19. JSON Pretty Print
```sql
pager jq .;

SELECT JSON_OBJECT('id', 1, 'name', 'Ajay');

-- Formats JSON output (requires jq).
```

## 20. CSV Export
```sql
pager sed 's/\t/,/g' > /tmp/output.csv;

SELECT user, host FROM mysql.user;

-- Converts tab-separated output into CSV.
```

## 21. View Output in Vim
```sql
pager vim -R -;

SELECT * FROM mysql.user;

-- Opens results directly in Vim (read-only).
```

## 22. Send Output via Mail
```sql
pager mail -s "MySQL Output" you@example.com;

SELECT * FROM mysql.user;

-- Sends query results via email.
```

## 23. Real-Time Monitoring with watch
```sql
pager watch -n 2;

SHOW FULL PROCESSLIST;

-- Re-runs the command every 2 seconds like a dashboard.
```

## 24. Preview First Lines with head
```sql
pager head -20;

SELECT * FROM mysql.user;

-- Shows only the first 20 lines of results.
```

## 25. Preview Last Lines with tail
```sql
pager tail -20;

SELECT * FROM mysql.general_log;

-- Shows only the last 20 lines of results.
```
