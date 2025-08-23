## MySQL PAGER Command

The `pager` command in the MySQL client lets you **pipe query output** through external programs like `grep`, `less`, `tee`, `awk`, etc.  
This is extremely useful for DBAs when handling **large outputs**, filtering results or saving query logs.

```sql
P1. Exclude Sleep Connections
pager grep -v Sleep;

SHOW FULL PROCESSLIST;
Shows all connections except those in "Sleep" state.

P2. Send Output to Standard Console
pager stdout;
Resets output to normal console immediately.

P3. Checksum Query Output
pager md5sum;

SELECT * FROM table_name;
Generates an MD5 checksum of results.

P4. View Results Page by Page
pager less -S;
Scroll results page by page (-S prevents line wrapping).

P5. View Results One Screen at a Time
pager more;
Simpler pager, space to scroll, q to quit.

P6. Save Query Output to a File
pager cat > /tmp/output.txt;

SELECT * FROM mysql.user;
Saves results into /tmp/output.txt.

P7. Save and Show Results Together
pager tee /tmp/query_output.log;

SELECT NOW();
Displays results and saves them to a file.

P8. Filter Output with grep
pager grep root;

SELECT user, host FROM mysql.user;
Shows only rows containing "root".

P9. Highlight Matches with grep
pager grep --color -i lock;

SHOW FULL PROCESSLIST;
Highlights "lock" in output (-i = case-insensitive).

P10. Remove Blank Lines with sed
pager sed '/^$/d';

SHOW CREATE TABLE mysql.user;
Removes empty lines from output.

P11. Extract Specific Columns with awk
pager awk '{print $1, $2}';

SELECT user, host, plugin FROM mysql.user;
Prints only the first and second columns.

P12. Limit Output Width with cut
pager cut -c 1-50;

SELECT * FROM information_schema.tables;
Shows only the first 50 characters per line.

P13. Combine Multiple Pager Commands
pager grep "ERROR" | tee /tmp/errors.log | less -S;

SHOW ENGINE INNODB STATUS\G
Filters "ERROR", saves to file, and shows in pager.

P14. Disable Pager
nopager;
Restores normal output mode.

P15. Sort Results
pager sort;

SELECT user, host FROM mysql.user;
Sorts query output alphabetically.

P16. Count Output Lines
pager wc -l;

SELECT * FROM information_schema.tables;
Shows how many rows were printed.

P17. Reverse Output
pager tac;

SELECT user, host FROM mysql.user;
Displays results in reverse order.

P18. Compress Output on the Fly
pager gzip > /tmp/output.gz;

SELECT * FROM big_table;
Saves results directly as a compressed .gz file.

P19. JSON Pretty Print
pager jq .;

SELECT JSON_OBJECT('id', 1, 'name', 'Ajay');
Formats JSON output (requires jq).

P20. CSV Export
pager sed 's/\t/,/g' > /tmp/output.csv;

SELECT user, host FROM mysql.user;
Converts tab-separated output into CSV.

P21. View Output in Vim
pager vim -R -;

SELECT * FROM mysql.user;
Opens results directly in Vim (read-only).

P22. Send Output via Mail
pager mail -s "MySQL Output" you@example.com;

SELECT * FROM mysql.user;
Sends query results via email.

P23. Real-Time Monitoring with watch
pager watch -n 2;

SHOW FULL PROCESSLIST;
Re-runs the command every 2 seconds like a dashboard.

P24. Preview First Lines with head
pager head -20;

SELECT * FROM mysql.user;
Shows only the first 20 lines of results.

P25. Preview Last Lines with tail
pager tail -20;

SELECT * FROM mysql.general_log;
Shows only the last 20 lines of results.