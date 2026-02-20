### MySQL Upgrade Check

####Command to run **MySQL Shell (`mysqlsh`)**'s upgrade readiness check on a server and capture the results.  
---
Run:
```bash
mysqlsh user@endpoint:port -- util checkForServerUpgrade --target-version=TARGET_VERSION
```
