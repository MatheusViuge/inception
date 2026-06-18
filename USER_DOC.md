# USER_DOC.md — User Documentation

## Overview

This project runs a WordPress website served over HTTPS, backed by a MariaDB database. The entire stack runs locally inside Docker containers.

| Service   | Role                                 |
|-----------|--------------------------------------|
| NGINX     | Web server — HTTPS entry point (port 443) |
| WordPress | Application — PHP website            |
| MariaDB   | Database — stores all site data      |

The only port exposed to the outside is **443 (HTTPS)**. The other services communicate internally and are not directly accessible.

---

## Starting and Stopping the Project

All commands are run from the root of the repository (`~/inception`).

**Start the project:**
```bash
make up
```
This builds the images (if needed) and starts all three containers.

**Stop the containers (keep data):**
```bash
make down
```

**Stop and remove all data (full reset):**
```bash
make reset
```

**Check container status:**
```bash
make ps
```

**View live logs:**
```bash
make logs
```

---

## Accessing the Website

Before accessing the site, make sure your `/etc/hosts` file contains the following entry:

```
127.0.0.1 mviana-v.42.fr
```

Once the containers are running, open your browser and go to:

```
https://mviana-v.42.fr
```

The certificate is self-signed, so your browser will show a security warning. Click **Advanced** and then **Proceed** to continue.

---

## Accessing the Administration Panel

The WordPress admin panel is available at:

```
https://mviana-v.42.fr/wp-admin
```

---

## Credentials

All credentials are defined in the file:

```
srcs/.env
```

| Variable           | Description                     |
|--------------------|---------------------------------|
| `MYSQL_ROOT_PASSWORD` | MariaDB root password        |
| `MYSQL_USER`       | WordPress database user         |
| `MYSQL_PASSWORD`   | WordPress database user password|
| `WP_ADMIN_USER`    | WordPress administrator login   |
| `WP_ADMIN_PASSWORD`| WordPress administrator password|
| `WP_USER_USER`     | WordPress regular user login    |
| `WP_USER_PASSWORD` | WordPress regular user password |

> Keep this file private. Do not commit it to version control.

---

## Checking That Services Are Running

**Quick status check:**
```bash
make ps
```

Expected output — all three containers should show `Up`:

```
Name        Command       State                  Ports
-------------------------------------------------------------------
mariadb     /entrypoint.sh   Up      3306/tcp
wordpress   /entrypoint.sh   Up      9000/tcp
nginx       /entrypoint.sh   Up      0.0.0.0:443->443/tcp
```

**Check logs for a specific service:**
```bash
docker-compose -f srcs/docker-compose.yml logs mariadb
docker-compose -f srcs/docker-compose.yml logs wordpress
docker-compose -f srcs/docker-compose.yml logs nginx
```

**Verify the database and user:**
```bash
docker exec -it mariadb mariadb -u root -p \
  -e "SELECT User, Host FROM mysql.user; SHOW DATABASES;"
```
