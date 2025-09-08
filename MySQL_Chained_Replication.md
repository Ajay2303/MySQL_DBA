# MySQL 8 Chained Replication (GTID Recommended)

This guide sets up **end-to-end chained replication** on Ubuntu with **MySQL 8** using **GTID-based replication**. It also includes a non-GTID alternative and troubleshooting notes.

---

## Topology

* **Server 1 (S1)** – Master
* **Server 2 (S2)** – Intermediate (replica of S1, master for S3)
* **Server 3 (S3)** – Final replica
* **Replication user**: configured on each master for its replica

---

## 0. Prerequisites (on all servers)

```bash
# Install MySQL if not installed
sudo apt update
sudo apt install -y mysql-server

# Enable and start MySQL
sudo systemctl enable --now mysql

# Configure MySQL to listen on all interfaces
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# Optional: allow port 3306 if firewall is enabled
sudo ufw allow 3306/tcp

# Restart MySQL to apply changes
sudo systemctl restart mysql
```

---

## 1. Configure `mysqld.cnf`

Edit `/etc/mysql/mysql.conf.d/mysqld.cnf` and append under **\[mysqld]**.

### S1 (Master)

```ini
[mysqld]
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_expire_logs_seconds = 2592000
max_binlog_size = 100M
binlog_format = ROW

gtid_mode = ON
enforce_gtid_consistency = ON
log_slave_updates = ON
```

### S2 (Replica of S1 + Master for S3)

```ini
[mysqld]
server-id = 2
log_bin = /var/log/mysql/mysql-bin.log
relay_log = /var/log/mysql/mysql-relay-bin.log
binlog_expire_logs_seconds = 2592000
max_binlog_size = 100M
binlog_format = ROW

gtid_mode = ON
enforce_gtid_consistency = ON
log_slave_updates = ON
read_only = ON
super_read_only = ON
```

### S3 (Replica only)

```ini
[mysqld]
server-id = 3
relay_log = /var/log/mysql/mysql-relay-bin.log
binlog_format = ROW

gtid_mode = ON
enforce_gtid_consistency = ON
log_slave_updates = ON
read_only = ON
super_read_only = ON
```

Apply changes:

```bash
sudo systemctl restart mysql
```

---

## 2. Create Replication Users

Create a dedicated replication user on each master for the next server.

### On S1 (allow S2)

```sql
CREATE USER 'replica_user'@'S2_IP' IDENTIFIED WITH mysql_native_password BY 'strong_password';
GRANT REPLICATION SLAVE ON *.* TO 'replica_user'@'S2_IP';
FLUSH PRIVILEGES;
```

### On S2 (allow S3)

```sql
CREATE USER 'replica_user'@'S3_IP' IDENTIFIED WITH mysql_native_password BY 'strong_password';
GRANT REPLICATION SLAVE ON *.* TO 'replica_user'@'S3_IP';
FLUSH PRIVILEGES;
```

---

## 3. Seed Data to Replicas

### Using `mysqldump` with GTID metadata

On **S1**:

```bash
mysqldump -u root -p --all-databases --single-transaction --master-data=2 \
  --triggers --routines --events --set-gtid-purged=ON > /tmp/fullseed.sql
scp /tmp/fullseed.sql user@S2_IP:/tmp/
```

On **S2**:

```bash
mysql -u root -p < /tmp/fullseed.sql
```

Repeat from **S2 → S3** (dump on S2, import on S3).

---

## 4. Start Replication: S1 → S2

On **S2**:

```sql
STOP REPLICA;
RESET REPLICA ALL;

CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='S1_IP',
  SOURCE_USER='replica_user',
  SOURCE_PASSWORD='strong_password',
  SOURCE_AUTO_POSITION=1,
  SOURCE_PORT=3306;

START REPLICA;
```

Verify:

```sql
SHOW REPLICA STATUS\G
```

Expect:

* `Replica_IO_Running: Yes`
* `Replica_SQL_Running: Yes`
* `Seconds_Behind_Source ~ 0`

---

## 5. Start Replication: S2 → S3

On **S3**:

```sql
STOP REPLICA;
RESET REPLICA ALL;

CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='S2_IP',
  SOURCE_USER='replica_user',
  SOURCE_PASSWORD='strong_password',
  SOURCE_AUTO_POSITION=1,
  SOURCE_PORT=3306;

START REPLICA;
```

Verify:

```sql
SHOW REPLICA STATUS\G
```

Expect:

* `Replica_IO_Running: Yes`
* `Replica_SQL_Running: Yes`

---

## 6. Functional Test

On **S1**:

```sql
CREATE DATABASE db_1;
USE db_1;
CREATE TABLE table_1(Id INT PRIMARY KEY);
INSERT INTO table_1 VALUES (1);
```

On **S2** and **S3**:

```sql
SELECT * FROM db_1.table_1;
```

You should see the inserted row on both S2 and S3.

---

## Non-GTID Alternative

Replace `SOURCE_AUTO_POSITION=1` with:

```sql
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='S1_IP',
  SOURCE_USER='replica_user',
  SOURCE_PASSWORD='strong_password',
  SOURCE_LOG_FILE='mysql-bin.000001',
  SOURCE_LOG_POS=position_value;
```

Capture the correct log file and position from `--master-data` during the dump.

---

## Troubleshooting

* **Server not configured as replication source**

  * Verify `log_bin` and `server-id` on the master.

* **Slave I/O thread stops due to duplicate server UUIDs**

  * Remove `auto.cnf` on the replica and restart MySQL.

* **Replica not catching up**

  * Check `SHOW REPLICA STATUS\G` for errors.
  * Validate firewall, user privileges, and GTID consistency.

---

## Done

You now have a clean **chained replication setup (S1 → S2 → S3)** using GTID-based replication on MySQL 8.
