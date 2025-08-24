# Memory Usage Script

This script remotely connects to a server via **SSH** and captures **memory usage** (`free -h`).  
It then formats the output into a clean **HTML email** with a table showing memory and swap usage.  

---

## Features
- Uses `sshpass` for **password-based SSH authentication**  
- Captures **hostname, timestamp, memory, and swap** usage  
- Converts `free -h` output into an **HTML email report**  
- Sends email via **sendmail** in tabular format  

---

## Script

```bash
#!/bin/bash

# SSH and email configuration
SSH_USER=""
SSH_HOST=""
SSH_PORT=""
SSH_PASS=""
TO_EMAIL=""
SUBJECT=""
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Run free -h remotely and capture raw output
MEMORY_OUTPUT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "hostname && echo 'Timestamp: $DATE' && echo && free -h")

# Extract hostname, timestamp, and memory lines
HOSTNAME=$(echo "$MEMORY_OUTPUT" | head -n 1)
TIMESTAMP=$(echo "$MEMORY_OUTPUT" | sed -n 2p)
HEADER=$(echo "$MEMORY_OUTPUT" | sed -n 4p)
MEM_LINE=$(echo "$MEMORY_OUTPUT" | sed -n 5p)
SWAP_LINE=$(echo "$MEMORY_OUTPUT" | sed -n 6p)

# Convert to proper HTML table
HTML_TABLE="<table border='1' cellpadding='8' cellspacing='0' style='border-collapse: collapse; font-family: Arial, sans-serif;'>
<tr style='background-color:#f2f2f2; font-weight: bold;'>
  <td>Type</td>"

# Add headers
for col in $HEADER; do
  HTML_TABLE+="<td>$col</td>"
done
HTML_TABLE+="</tr>"

# Add Mem row
HTML_TABLE+="<tr><td><b>Mem</b></td>"
for col in $(echo "$MEM_LINE" | cut -d ':' -f2); do
  HTML_TABLE+="<td>$col</td>"
done
HTML_TABLE+="</tr>"

# Add Swap row
HTML_TABLE+="<tr><td><b>Swap</b></td>"
for col in $(echo "$SWAP_LINE" | cut -d ':' -f2); do
  HTML_TABLE+="<td>$col</td>"
done
HTML_TABLE+="</tr></table>"

# Compose and send HTML email
{
echo "To: $TO_EMAIL"
echo "Subject: $SUBJECT"
echo "Content-Type: text/html"
echo ""
echo "<html><body>"
echo "<p>Hi Team,</p>"
echo "<p>Find the memory usage report from server <b>[$HOSTNAME]</b>.</p>"
echo "<p>$TIMESTAMP</p>"
echo "$HTML_TABLE"
echo "<p>Regards,<br>Monitoring Team</p>"
echo "</body></html>"
} | /usr/sbin/sendmail -t
```