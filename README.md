*This project has been created as part of the 42 curriculum by mviana-v.*

# Inception

## Description

Inception is a system administration project from the 42 curriculum. The goal is to set up a small infrastructure composed of multiple services running inside Docker containers, orchestrated with Docker Compose.

The stack consists of three containers, each built from scratch using a custom Dockerfile based on Debian Bookworm:

- **NGINX** — serves the website over HTTPS (TLS 1.2/1.3) on port 443, the only externally exposed port.
- **WordPress + PHP-FPM** — the web application, installed and configured automatically via `wp-cli`.
- **MariaDB** — the relational database storing all WordPress data.

All containers communicate over a private Docker bridge network. No pre-built images from Docker Hub are used. Data is persisted through bind-mount volumes on the host machine.

### Docker in this project

Docker is used to isolate each service in its own container, making the stack reproducible and portable. Each service has its own `Dockerfile` that installs only the packages it needs, keeping images lean. Docker Compose orchestrates the startup order, networking, and volumes between the three services.

### Design Choices

**Virtual Machines vs Docker**

Virtual machines emulate an entire operating system, including a full kernel, which makes them heavier and slower to start. Docker containers share the host kernel and isolate only the user space, making them much more lightweight and faster to spin up. For this project, Docker was chosen because each service only needs its own process environment, not a full OS.

**Secrets vs Environment Variables**

Environment variables (via `.env` file) were used in this project to pass credentials to containers at runtime. They are practical for local development and school environments. Docker Secrets are the production-grade alternative — they store sensitive data encrypted on disk and inject it into containers as files, never exposing them in environment listings (`docker inspect`, `ps`). For a production deployment, secrets would be the correct choice.

**Docker Network vs Host Network**

With `network: host`, a container shares the host's network stack directly — no isolation, any port the container opens is open on the host. This project uses a custom bridge network (`inception`), which gives each container its own network namespace. Containers can reach each other by name (e.g., `mariadb:3306`), but are invisible to the outside except through explicitly published ports. This is the correct approach for isolation and security.

**Docker Volumes vs Bind Mounts**

Docker-managed volumes store data in Docker's internal storage (`/var/lib/docker/volumes/`) and are fully managed by Docker. Bind mounts map a specific host directory directly into the container. This project uses bind mounts configured as named volumes, pointing to `/home/mviana/data/mariadb` and `/home/mviana/data/wordpress`. This makes the data location explicit and easy to inspect or back up from the host, which is appropriate for a school environment.

---

## Instructions

### Prerequisites

- Linux VM (Debian Bookworm recommended)
- Docker and `docker-compose` (standalone) installed
- `make` installed
- `sudo` access

### Setup

**1. Clone the repository:**
```bash
git clone https://github.com/MatheusViuge/inception.git
cd inception
```

**2. Create the host data directories:**
```bash
mkdir -p /home/mviana/data/mariadb
mkdir -p /home/mviana/data/wordpress
```

**3. Configure credentials:**

Edit `srcs/.env` with your passwords and settings. See `DEV_DOC.md` for the full list of variables.

**4. Add the domain to `/etc/hosts`:**
```bash
echo "127.0.0.1 mviana-v.42.fr" | sudo tee -a /etc/hosts
```

**5. Build and start:**
```bash
make up
```

**6. Access the site:**

Open `https://mviana-v.42.fr` in your browser. Accept the self-signed certificate warning.

The admin panel is at `https://mviana-v.42.fr/wp-admin`.

### Common Commands

| Command       | Description                                  |
|---------------|----------------------------------------------|
| `make up`     | Build and start all containers               |
| `make down`   | Stop containers, preserve data               |
| `make clean`  | Stop containers and remove volumes           |
| `make fclean` | Remove containers, volumes, and images       |
| `make reset`  | Full wipe and rebuild from scratch           |
| `make ps`     | Show container status                        |
| `make logs`   | Follow logs for all containers               |

For more detail, see [`USER_DOC.md`](USER_DOC.md) and [`DEV_DOC.md`](DEV_DOC.md).

---

## Resources

### Docker & Infrastructure

- [Docker official documentation](https://docs.docker.com/)
- [Docker Compose reference](https://docs.docker.com/compose/)
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [MariaDB documentation](https://mariadb.com/kb/en/)
- [WordPress CLI (wp-cli)](https://wp-cli.org/)
- [OpenSSL cookbook — TLS certificates](https://www.feistyduck.com/library/openssl-cookbook/)

### Articles & Tutorials

- [Docker networking overview](https://docs.docker.com/network/)
- [Docker volumes vs bind mounts](https://docs.docker.com/storage/volumes/)
- [PHP-FPM configuration guide](https://www.php.net/manual/en/install.fpm.configuration.php)
- [Understanding Docker secrets](https://docs.docker.com/engine/swarm/secrets/)

### AI Usage

Claude (Anthropic) was used as a development assistant throughout this project for the following tasks:

- **Debugging** — diagnosing entrypoint failures in MariaDB (bootstrap mode, volume initialization behavior, `set -e` interaction with container restarts).
- **Documentation** — generating `USER_DOC.md`, `DEV_DOC.md`, and this `README.md` based on the actual implemented stack.

All generated code and documentation was reviewed, tested, and validated on the actual VM before inclusion in the project.
