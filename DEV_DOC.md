# DEV_DOC.md — Developer Documentation

## Prerequisites

- A Linux virtual machine (Debian Bookworm recommended)
- Docker installed and running
- `docker-compose` standalone (v1.29+)
- `sudo` access
- `make` installed

Verify your setup:
```bash
docker --version
docker-compose --version
```

---

## Project Structure

```
inception/
├── Makefile
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   └── tools/entrypoint.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   └── tools/entrypoint.sh
        └── nginx/
            ├── Dockerfile
            ├── conf/nginx.conf
            └── tools/entrypoint.sh
```

---

## Configuration Files

### `.env`

Located at `srcs/.env`. This file defines all secrets and environment variables injected into the containers at runtime.

```env
DOMAIN_NAME=mviana-v.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_PASSWORD=<password>
MYSQL_ROOT_PASSWORD=<password>

WP_TITLE=Inception
WP_ADMIN_USER=mviana-v_root
WP_ADMIN_PASSWORD=<password>
WP_ADMIN_EMAIL=mviana-v@42.fr

WP_USER_USER=mviana-v_user
WP_USER_PASSWORD=<password>
WP_USER_EMAIL=mviana-v_user@42.fr
```

> The admin username must not contain `admin` or `administrator`.

### `/etc/hosts`

The domain must resolve locally. Add this entry to `/etc/hosts` on the VM:

```
127.0.0.1 mviana-v.42.fr
```

---

## Building and Launching the Project

All `make` commands are run from the repository root.

### First-time setup

```bash
# Create the host directories for persistent data
mkdir -p /home/mviana/data/mariadb
mkdir -p /home/mviana/data/wordpress

# Build images and start all containers
make up
```

### Common Makefile targets

| Command        | Description                                         |
|----------------|-----------------------------------------------------|
| `make up`      | Build images (if needed) and start all containers   |
| `make down`    | Stop and remove containers (data is preserved)      |
| `make build`   | Build or rebuild images without starting            |
| `make clean`   | Stop containers and remove volumes                  |
| `make fclean`  | `clean` + remove all Docker images                  |
| `make reset`   | Full reset: removes containers, volumes, images, and host data, then rebuilds from scratch |
| `make ps`      | Show container status                               |
| `make logs`    | Follow logs for all containers                      |
| `make config`  | Validate `docker-compose.yml`                       |

---

## Managing Containers and Volumes

**Rebuild a single service without cache:**
```bash
docker-compose -f srcs/docker-compose.yml build --no-cache mariadb
```

**Restart a single container:**
```bash
docker-compose -f srcs/docker-compose.yml restart nginx
```

**Open a shell inside a container:**
```bash
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash
```

**Inspect the internal network:**
```bash
docker network inspect srcs_inception
```

**List volumes:**
```bash
docker volume ls
```

**Inspect a volume:**
```bash
docker volume inspect srcs_mariadb_data
```

---

## Data Persistence

All persistent data is stored on the VM host under `/home/mviana/data/`:

| Path                          | Mounted at (in container) | Service   |
|-------------------------------|---------------------------|-----------|
| `/home/mviana/data/mariadb`   | `/var/lib/mysql`          | MariaDB   |
| `/home/mviana/data/wordpress` | `/var/www/html`           | WordPress |

These are configured as **bind-mount named volumes** in `docker-compose.yml`:

```yaml
volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/mviana/data/mariadb
```

This means:
- Data survives `docker-compose down` and container restarts.
- Running `make clean` or `make reset` removes the Docker volumes but **`make reset` also clears the host directories**, making the next `make up` a true clean start.
- The NGINX container mounts the WordPress volume as **read-only** (`ro`) since it only serves files.

---

## Initialization Logic

### MariaDB

On first start with an empty data directory, the entrypoint:
1. Runs `mariadb-install-db` to create the system database.
2. Uses `mysqld --bootstrap` to execute setup SQL — creates the `wordpress` database, the `wp_user` account, and sets the root password.
3. On subsequent starts, the init block is skipped if `/var/lib/mysql/mysql` already exists.

### WordPress

On first start, the entrypoint:
1. Waits for MariaDB to accept connections.
2. Uses `wp-cli` to download WordPress, generate `wp-config.php`, install the site, and create both user accounts.
3. Skips installation if `wp-config.php` already exists.

### NGINX

On start, the entrypoint generates a self-signed TLS certificate with `openssl` if one does not already exist, then starts NGINX in the foreground.
