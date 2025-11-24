# MySQL on Docker — Installation & Connection Guide (5.5, 5.7, 8.0)

 Step-by-step instructions to install and run MySQL inside Docker, with persistent data, custom config, networking, and multi-version setup.

---

## Prerequisites
* Linux host (Ubuntu, Debian, CentOS) or WSL2  
* Docker Engine installed (`docker.io`, `docker-ce`, or Docker Desktop)  
* Basic CLI familiarity  
 Note: MySQL 5.5 and 5.7 are EOL. Prefer MySQL 8.0 for production.

---

## Install Docker (Ubuntu / WSL)
```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
docker --version
```

### MySQL 8.0
```
docker pull mysql:8.0
docker run -d --name mysql80 -e MYSQL_ROOT_PASSWORD=ChangeMe! -p 3308:3306 -v /home/$(whoami)/mysql80_data:/var/lib/mysql mysql:8.0
docker logs -f mysql80
mysql -h 127.0.0.1 -P 3308 -u root -p
```
### MySQL 5.7
```
docker pull mysql:5.7
docker run -d --name mysql57 -e MYSQL_ROOT_PASSWORD=Root@123 -p 3306:3306 -v /home/$(whoami)/mysql57_data:/var/lib/mysql mysql:5.7
mysql -h 127.0.0.1 -P 3306 -u root -p
```
### MySQL 5.5 (Legacy)
```
docker pull mysql:5.5 || docker pull mysql/mysql-server:5.5
docker run -d --name mysql55 -e MYSQL_ROOT_PASSWORD=Root@123 -p 3307:3306 mysql:5.5
mysql -h 127.0.0.1 -P 3307 -u root -p
```
---
### Mounting Volumes & Persisting Data
```
Host directory: -v /home/ajay/mysql57_data:/var/lib/mysql
```
### Named volume:
```
docker volume create mysql57_data
docker run -d -v mysql57_data:/var/lib/mysql --name mysql57 -e MYSQL_ROOT_PASSWORD=Root@123 mysql:5.7
Reason: Ensures MySQL data persists even if containers are removed.
```

### Custom Configuration (my.cnf)
```
[mysqld]
max_connections = 200
innodb_buffer_pool_size = 512M
```
```
docker run -d \
  --name mysql57 \
  -v /home/$(whoami)/mysql57_data:/var/lib/mysql \
  -v /home/$(whoami)/mysql-config:/etc/mysql/conf.d \
  -e MYSQL_ROOT_PASSWORD=Root@123 \
  mysql:5.7
Reason: Customize MySQL performance and limits for production/testing.
```
---
### Networking & Access
```
Host access: -p <host>:<container>
```
### Container network:
```
docker network create app-network
docker run -d --name mysql57 --network app-network -e MYSQL_ROOT_PASSWORD=Root@123 mysql:5.7
docker run -d --network app-network --name myapp myapp-image
Reason: Allows host access and secure container-to-container communication by name.
```
---
### Docker Compose — Multiple Versions
```
version: '3.8'
services:
  mysql80:
    image: mysql:8.0
    container_name: mysql80
    environment: { MYSQL_ROOT_PASSWORD: root80 }
    ports: ["3308:3306"]
    volumes: ["mysql80_data:/var/lib/mysql"]

  mysql57:
    image: mysql:5.7
    container_name: mysql57
    environment: { MYSQL_ROOT_PASSWORD: root57 }
    ports: ["3306:3306"]
    volumes: ["mysql57_data:/var/lib/mysql"]

  mysql55:
    image: mysql:5.5
    container_name: mysql55
    environment: { MYSQL_ROOT_PASSWORD: root55 }
    ports: ["3307:3306"]
    volumes: ["mysql55_data:/var/lib/mysql"]

volumes: { mysql80_data: {}, mysql57_data: {}, mysql55_data: {} }
Reason: Quickly spin up multiple MySQL versions with isolated ports, volumes, and configs.
```
---
### Useful Commands:
```
docker ps -a               # List containers
docker stop mysql57        # Stop container
docker start mysql57       # Start container
docker logs -f mysql57     # View logs
docker rm -f mysql55       # Remove container
docker rmi mysql:5.5       # Remove image
docker volume ls           # List volumes
docker volume inspect mysql57_data
Reason: Standard commands to manage containers, inspect logs, and verify volumes.
```
---
Prepared for GitHub by Ajay.
