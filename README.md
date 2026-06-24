*This project has been created as part of the 42 curriculum by tvaroux.*

## Description

Inception is a 42 project focused on building and understanding a small containerized web infrastructure with Docker.

The goal of this project is to run a complete WordPress website using several independent Docker containers. Each service is built from its own Dockerfile and is managed together with Docker Compose.

The infrastructure contains:

- NGINX as the HTTPS entry point
- WordPress running with PHP-FPM
- MariaDB as the database server
- Docker volumes for persistent data
- Docker secrets for sensitive passwords
- A dedicated Docker bridge network for internal service communication

The request flow is:


```
┌─────────────────────────────────────────────────────────────┐
│                        VM (Ubuntu 22.04)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Docker Compose                      │  │
│  │  ┌─────────┐    ┌─────────────┐    ┌─────────────┐    │  │
│  │  │  NGINX  │◀───│  WordPress  │◀───│   MariaDB   │    │  │
│  │  │ :443    │    │  php-fpm    │    │   :3306     │    │  │
│  │  │ TLS 1.2+│    │  wp-cli     │    │             │    │  │
│  │  └────┬────┘    └──────┬──────┘    └──────┬──────┘    │  │
│  │       │                │                  │           │  │
│  │       └────────────────┴──────────────────┘           │  │
│  │                 tvaroux_network (bridge)              │  │
│  │                                                       │  │
│  │       [volumes: wordpress, mariadb]                   │  │
│  └──────────────── │  ───────────────────────────────────┘  │
│                    │                                        │
│                  Mount                                      │
│                    │                                        │
│          [Docker volumes]                                   │
│  /var/lib/docker/volumes/srcs_wordpress_data/_data          │
│  /var/lib/docker/volumes/srcs_mariadb_data/_data            │
│                    │                                        │
│                Bind (o: bind)                               │
│                    │                                        │
│          [device volumes]                                   │
│            /home/tvaroux/data/wordpress                     │
│            /home/tvaroux/data/mariadb                       │
└─────────────────────────────────────────────────────────────┘
```


```text
Browser
  |
  | HTTPS :443
  v
NGINX
  |
  | FastCGI :9000
  v
WordPress / PHP-FPM
  |
  | SQL :3306
  v
MariaDB
```

Docker is used to isolate each service in its own container while keeping the whole stack reproducible. The source files are organized by service under `srcs/requirements/`, with one Dockerfile and related configuration files for each component.

Main source layout:

```text
srcs/
  docker-compose.yml
  requirements/
    mariadb/
      Dockerfile
      conf/
      tools/
    nginx/
      Dockerfile
      conf/
    wordpress/
      Dockerfile
      conf/
      tools/
  vm/
secrets/
Makefile
```

## Instructions

### Prerequisites

Before running the project, make sure Docker Engine and Docker Compose are installed.

Create the required data directories on the host:

```bash
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

Create `srcs/.env` with the required non-secret configuration values, for example:

```env
YOUR_LEARNER_USERNAME=tvaroux
DOMAIN_NAME=tvaroux.42.fr
MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser
WP_ADMIN_USER=admin
WP_ADMIN_EMAIL=admin@example.com
WP_EDITOR_USER=editor
WP_EDITOR_EMAIL=editor@example.com
```

Create the secret files under `secrets/`:

```bash
echo -n "db_password_here" > secrets/db_password.txt
echo -n "db_root_password_here" > secrets/db_root_password.txt
echo -n "wp_admin_password_here" > secrets/wp_admin_password.txt
echo -n "wp_editor_password_here" > secrets/wp_editor_password.txt
```

These files must not be committed to the repository.

### Build and run

Run the stack from the repository root:

```bash
make up
```

This command validates the Compose configuration, builds the service images, and starts the containers in detached mode.

### Access

Once the containers are running, the site can be accessed through HTTPS:

```text
https://tvaroux.42.fr
```

For a local VM or port-forwarded environment, this may also be tested with:

```text
https://127.0.0.1
```

The WordPress admin panel is available at:

```text
https://tvaroux.42.fr/wp-admin
```

### Useful commands

```bash
make build
```

Rebuild the Docker images.

```bash
make up-no-build
```

Start existing images without rebuilding.

```bash
make down
```

Stop and remove the containers.

```bash
make down-v
```

Stop the stack and remove Docker volumes.

```bash
make re
```

Restart the stack.

```bash
make curl-https
```

Test the HTTPS endpoint with `curl`.

```bash
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

Inspect the runtime state of each container.

## Project description

### Main design choices

This project separates the infrastructure into three containers instead of installing all services directly on one machine.

- NGINX is the only service exposed to the host on port `443`.
- WordPress communicates with MariaDB through the internal Docker network.
- MariaDB data and WordPress files are stored in persistent volumes.
- Passwords are provided through Docker secrets instead of plain environment variables.
- Each service is built from a custom Dockerfile to understand how the stack works internally.

### Virtual Machines vs Docker

| Point | Virtual Machine | Docker Container |
|---|---|---|
| Virtualization level | Virtualizes hardware | Virtualizes processes |
| Operating system | Runs a full guest OS | Shares the host kernel |
| Startup time | Usually slower | Usually faster |
| Resource usage | Heavier | Lighter |
| Isolation | Strong OS-level isolation | Process isolation with namespaces and cgroups |

A virtual machine is useful when a complete isolated operating system is needed. Docker is more lightweight and is better suited for packaging and running individual services.

In this project, Docker runs inside a VM because the 42 subject requires the project to be executed in a virtualized environment.

### Secrets vs Environment Variables

| Point | Docker secrets | Environment variables |
|---|---|---|
| Best use | Passwords and sensitive data | Non-sensitive configuration |
| Exposure | Mounted as files under `/run/secrets/` | Visible in the process environment |
| Risk | Lower for credentials | Higher for credentials |
| Example | Database password | Domain name, database name, username |

This project uses Docker secrets for passwords:

- `db_password`
- `db_root_password`
- `wp_admin_password`
- `wp_editor_password`

Environment variables are used only for non-secret configuration such as the domain name, database name, and usernames.

### Docker Network vs Host Network

| Point | Docker bridge network | Host network |
|---|---|---|
| Isolation | Containers use a private network | Containers use the host network directly |
| Service discovery | Containers can resolve each other by name | No Docker DNS isolation |
| Port exposure | Only selected ports are published | Services may bind directly to host ports |
| Security | More controlled | Less isolated |

This project uses a dedicated Docker bridge network. The containers communicate by service name, such as `wordpress` and `mariadb`.

Only the NGINX container exposes port `443` to the host. MariaDB and WordPress are not directly exposed outside the Docker network.

### Docker Volumes vs Bind Mounts

| Point | Docker volumes | Bind mounts |
|---|---|---|
| Managed by | Docker | Host filesystem |
| Portability | More portable | Depends on host paths |
| Visibility | Managed with Docker commands | Directly visible on the host |
| Use case | Persistent application data | Direct host-file access |

This project uses Docker volumes with bind-style driver options. This keeps the data persistent under:

```text
/home/tvaroux/data/mariadb
/home/tvaroux/data/wordpress
```

The MariaDB volume stores database files, and the WordPress volume stores the WordPress website files. This allows the data to survive container rebuilds and restarts.

## Resources

### Official documentation

- Docker documentation: https://docs.docker.com/
- Docker Compose file reference: https://docs.docker.com/reference/compose-file/
- Docker Compose secrets: https://docs.docker.com/compose/how-tos/use-secrets/
- Docker volumes: https://docs.docker.com/engine/storage/volumes/
- Docker networking: https://docs.docker.com/compose/how-tos/networking/
- NGINX documentation: https://nginx.org/en/docs/
- NGINX SSL module: https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- NGINX FastCGI module: https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- MariaDB documentation: https://mariadb.com/kb/en/documentation/
- MariaDB install database tool: https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db
- WordPress documentation: https://wordpress.org/documentation/
- WP-CLI handbook: https://make.wordpress.org/cli/handbook/
- PHP-FPM documentation: https://www.php.net/manual/en/install.fpm.php
- GNU Make manual: https://www.gnu.org/software/make/manual/make.html
- VirtualBox manual: https://www.virtualbox.org/manual/UserManual.html

### Additional references

- RFC 8446, TLS 1.3: https://datatracker.ietf.org/doc/html/rfc8446
- OpenSSL documentation: https://www.openssl.org/docs/
- Alpine Linux documentation: https://docs.alpinelinux.org/
- Alpine Linux package database: https://pkgs.alpinelinux.org/

### AI usage

AI was used as a learning and development assistant during this project.

It was used for:

- Explaining Docker concepts such as images, containers, volumes, networks, and secrets
- Comparing virtual machines and Docker containers
- Reviewing Docker Compose design choices
- Helping structure shell entrypoint scripts
- Suggesting verification commands
- Organizing documentation and README content

AI was not used as a replacement for understanding the project. The final design decisions, testing, debugging, and validation were performed by the student.
