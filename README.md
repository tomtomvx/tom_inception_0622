*This project has been created as part of the 42 curriculum by tvaroux.*

# Inception

## Description

This project is about building a web infrastructure with Docker.

It runs a WordPress website with three containers:

- `nginx`: the only public entry point, listening on HTTPS port `443`
- `wordpress`: WordPress served by PHP-FPM on the internal port `9000`
- `mariadb`: the database server used by WordPress on the internal port `3306`

The full stack is declared in `srcs/docker-compose.yml`. Each service has its
own Dockerfile, configuration files, and startup logic under
`srcs/requirements/<service>/`.

Architecture:

```text
┌─────────────────────────────────────────────────────────────┐
│                        VM (Ubuntu 22.04)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Docker Compose                      │  │
│  │  ┌─────────┐    ┌─────────────┐    ┌─────────────┐    │  │
│  │  │  NGINX  │◀───│  WordPress  │◀───│   MariaDB   │    │  │
│  │  │         │    │  php-fpm    │    │             │    │  │
│  │  │         │    │  wp-cli     │    │             │    │  │
│  │  └────┬────┘    └──────┬──────┘    └──────┬──────┘    │  │
│  │       │                │                  │           │  │
│  │       └────────────────┴──────────────────┘           │  │
│  │                 network_cake (bridge)                 │  │
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

Request flow:

```text
Browser
  |
  | HTTPS :443
  v
NGINX
  |
  | FastCGI wordpress:9000
  v
WordPress / PHP-FPM
  |
  | SQL mariadb:3306
  v
MariaDB
```

Main source layout:

```text
.
|-- Makefile
|-- README.md
|-- README-jp.md
|-- secrets/
|   `-- .gitignore
`-- srcs/
    |-- .env_sample
    |-- docker-compose.yml
    `-- requirements/
        |-- mariadb/
        |   |-- Dockerfile
        |   |-- conf/zzz-mariadb.cnf
        |   `-- tools/entrypoint.sh
        |-- nginx/
        |   |-- Dockerfile
        |   `-- conf/zzz-nginx.conf
        `-- wordpress/
            |-- Dockerfile
            |-- conf/www.conf
            |-- conf/docker-php-memlimit.ini
            `-- tools/entrypoint.sh
```

Docker is used to isolate services and make the same infrastructure reproducible
from source. Docker Compose manages the three services, the dedicated bridge
network, persistent volumes, `.env` configuration, and Docker secrets.

## Instructions

### Prerequisites

- Docker Engine and Docker Compose must be installed.
- The project is intended to run in a VM. The host OS used here is Ubuntu 22.04.
- Copy `srcs/.env_sample` to `srcs/.env` and edit it if necessary.
- Create Docker secret files under `secrets/`. Do not commit them to Git.
- You may need to add the project domain to the host's `/etc/hosts`.
- Create host data directories under `/home/tvaroux/data/` for MariaDB and
  WordPress.

### Setup

Move to the project root:

```sh
cd <your_repository>
```

### Create host data directories

The Compose volumes bind to host directories, so create them before starting the
stack:

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

### Create `.env`

Create `srcs/.env` from `srcs/.env_sample`:

```sh
cp srcs/.env_sample srcs/.env
```

Example:

```env
DOMAIN_NAME=tvaroux.42.fr
MARIADB_PORT=3306

WP_ADMIN_USER=ado
WP_ADMIN_EMAIL=ado@example.com
WP_USER=wpeditor
WP_USER_EMAIL=editor@example.com
```

The WordPress administrator username must not contain `admin` or `Admin`.

```sh
grep -i admin srcs/.env
```

### Create Docker secret files

Create the secret files read by Compose:

```sh
echo -n pw > secrets/db_password.txt
echo -n pw > secrets/wp_admin_password.txt
echo -n pw > secrets/wp_editor_password.txt
```

These files contain credentials and must not be committed to Git.

### Build and run

Build the images and start the containers:

```sh
make up
```

This runs:

```sh
docker compose -f ./srcs/docker-compose.yml up --detach --build
```

The site is available at:

```text
https://tvaroux.42.fr
https://127.0.0.1
https://localhost
```

The certificate is self-signed, so a browser warning is expected.

### Recommended Make targets

```sh
make up
```

Build and start the containers.

```sh
make build
```

Build the service images without starting containers.

```sh
make up-no-build
```

Start existing images without rebuilding.

```sh
make down
```

Stop and remove containers.

```sh
make down-v
```

Stop containers and remove Compose volumes.

```sh
make re
```

Run `make down` followed by `make up`.

```sh
make curl-https
```

Probe the HTTPS endpoint with `curl --insecure --verbose`.

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

Inspect container state, PID, status, and restart count.

## Main Design Choices

### Virtual Machines vs Docker

| Point | Virtual Machine | Docker Container |
| --- | --- | --- |
| Virtualization level | Hardware-level virtualization | OS-level process isolation |
| Kernel | Runs a guest OS and kernel | Shares the host kernel |
| Startup | Usually slower | Usually faster |
| Resource usage | Heavier | Lighter |
| Best use | Isolating a full OS | Packaging one service and its dependencies |

The subject may be evaluated in a VM. Inside that VM, using Docker containers is
more suitable than installing NGINX, PHP-FPM, and MariaDB directly on the
machine, because each service can be built, started, stopped, inspected, and
rebuilt independently.

### Secrets vs Environment Variables

| Point | Docker secrets | Environment variables |
| --- | --- | --- |
| Best use | Passwords and credentials | Non-sensitive configuration |
| Exposure | Mounted as files in `/run/secrets/` | Easier to see through process environments and inspect output |
| In this project | DB and WordPress passwords | Domain, database name, usernames |

Compose declares these Docker secrets:

- `db_password`
- `wp_admin_password`
- `wp_editor_password`

Startup scripts read secrets as files:

```sh
cat /run/secrets/db_password
```

Environment variables are used for non-secret configuration such as
`DOMAIN_NAME`, `MARIADB_DATABASE`, `MARIADB_USER`, `WP_ADMIN_USER`, and
`WP_USER`.

### Docker Network vs Host Network

| Point | Docker bridge network | Host network |
| --- | --- | --- |
| Isolation | Services stay in a private Docker network | Containers share the host network namespace |
| Name resolution | Docker DNS resolves service names | Compose service-name isolation is weaker |
| Port exposure | Only selected ports are published | Services can bind directly to host ports |
| In this project | `network_cake` | Not used |

This stack uses a dedicated bridge network named `network_cake`. Because Compose
adds a project prefix, Docker may display it as `srcs_network_cake`.

This allows:

- NGINX to reach WordPress as `wordpress:9000`
- WordPress to reach MariaDB as `mariadb:3306`
- MariaDB to remain private instead of being exposed to the host

Only port `443` is published to the host.

### Docker Volumes vs Bind Mounts

| Point | Docker volume | Bind mount |
| --- | --- | --- |
| Managed by | Docker | Host filesystem path |
| Portability | Less tied to a fixed host path | Directly depends on a host path |
| Visibility | Managed through Docker commands | Directly visible on the host |
| In this project | Compose volumes with the local driver | `driver_opts` binds to `/home/tvaroux/data/...` |

This project defines Docker volumes and uses bind options from the local driver:

```yaml
volumes:
  mariadb_data:
    driver: local
    driver_opts:
      device: /home/tvaroux/data/mariadb
      o: bind
      type: none
  wordpress_data:
    driver: local
    driver_opts:
      device: /home/tvaroux/data/wordpress
      o: bind
      type: none
```

As a result:

- MariaDB data remains under `/home/tvaroux/data/mariadb`
- WordPress files remain under `/home/tvaroux/data/wordpress`
- Recreating containers does not delete site data

## Resources

### Official documentation

- Docker documentation: https://docs.docker.com/
- Docker Compose file reference: https://docs.docker.com/reference/compose-file/
- Docker Compose secrets: https://docs.docker.com/compose/how-tos/use-secrets/
- Docker volumes: https://docs.docker.com/engine/storage/volumes/
- Docker networking: https://docs.docker.com/compose/how-tos/networking/
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Alpine Linux documentation: https://docs.alpinelinux.org/
- Alpine package database: https://pkgs.alpinelinux.org/
- NGINX documentation: https://nginx.org/en/docs/
- NGINX SSL module: https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- NGINX FastCGI module: https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- MariaDB documentation: https://mariadb.com/kb/en/documentation/
- `mariadb-install-db`: https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db
- WordPress documentation: https://wordpress.org/documentation/
- WP-CLI handbook: https://make.wordpress.org/cli/handbook/
- PHP-FPM documentation: https://www.php.net/manual/en/install.fpm.php
- OpenSSL documentation: https://www.openssl.org/docs/
- VirtualBox manual: https://www.virtualbox.org/manual/UserManual.html
- RFC 8446, TLS 1.3: https://datatracker.ietf.org/doc/html/rfc8446
- Docker Japanese edition: https://www.oreilly.com/library/view/docker/9784873117768/

### AI usage

AI was used as a learning and documentation assistant during this project.

It helped with:

- Organizing Docker concepts such as images, containers, volumes, networks, and
  secrets
- Comparing virtual machines and Docker containers
- Reviewing Docker Compose design choices
- Understanding NGINX, FastCGI, PHP-FPM, MariaDB initialization, and WP-CLI
  workflows
- Preparing defense commands and SQL checks
- Structuring this README and related study notes

AI was not used as a substitute for understanding the project. The final design
decisions, implementation, debugging, testing, and defense explanations were
checked by the submitter and can be explained by the submitter.
