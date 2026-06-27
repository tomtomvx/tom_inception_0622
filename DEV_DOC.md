# DEV_DOC - Developer Documentation

This document is a technical note for developers to set up, build, start,
check, and explain this Inception project from scratch.

## Project Layout

```text
.
|-- Makefile
|-- README.md
|-- README-jp.md
|-- USER_DOC.md
|-- USER_DOC-jp.md
|-- DEV_DOC.md
|-- DEV_DOC-jp.md
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

Each service has its own Dockerfile, configuration files, and startup script.
The full stack is defined in `srcs/docker-compose.yml`.

## Environment Setup From Scratch

Run project commands from the repository root.

```sh
cd <your_repository>
```

Requirements:

- Docker Engine
- Docker Compose plugin
- GNU Make
- `curl` and `openssl` for smoke tests

Check versions:

```sh
docker --version
docker compose version
make --version
```

### 1. Create Host Directories for Persistence

Compose volumes use the local driver with bind options. Host directories are
required before startup.

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

MariaDB files remain in `/home/tvaroux/data/mariadb`.
WordPress files remain in `/home/tvaroux/data/wordpress`.

### 2. Create `srcs/.env`

```sh
cp srcs/.env_sample srcs/.env
```

Sample:

```env
DOMAIN_NAME=tvaroux.42.fr

MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser
MARIADB_PORT=3306

WP_ADMIN_USER=ado
WP_ADMIN_EMAIL=ado@example.com
WP_USER=wpeditor
WP_USER_EMAIL=editor@example.com
```

Only non-secret configuration belongs in `.env`. Do not put passwords in
`.env`.

Important review point: the WordPress administrator username must not contain
`admin` or `Admin`.

### 3. Create Docker Secrets

Compose expects three secret files.

```sh
mkdir -p secrets
echo -n pw > secrets/db_password.txt
echo -n pw > secrets/wp_admin_password.txt
echo -n pw > secrets/wp_editor_password.txt
```

Secret mapping:

| Compose secret | Host file | Runtime path |
| --- | --- | --- |
| `db_password` | `../secrets/db_password.txt` | `/run/secrets/db_password` |
| `wp_admin_password` | `../secrets/wp_admin_password.txt` | `/run/secrets/wp_admin_password` |
| `wp_editor_password` | `../secrets/wp_editor_password.txt` | `/run/secrets/wp_editor_password` |

Entrypoint scripts read passwords as files. Because passwords are not placed in
normal environment variables, they are less likely to appear in `docker inspect`
or process environments.

### 4. Domain Setup

If the domain does not resolve, add it to `/etc/hosts` on the VM or evaluation
host.

```text
127.0.0.1 tvaroux.42.fr
```

## Build and Start

Main Makefile targets:

| Target | Purpose |
| --- | --- |
| `make` / `make all` / `make up` | Build images and start containers detached |
| `make build` | Build images only |
| `make up-no-build` | Start existing images without building |
| `make down` | Stop and remove containers |
| `make down-v` | Remove containers and Compose volumes |
| `make re` | Run `make down`, then `make up` |
| `make curl-https` | HTTPS test with `curl --insecure --verbose` |
| `make inspect-nginx` | Inspect the NGINX container |
| `make inspect-wordpress` | Inspect the WordPress container |
| `make inspect-mariadb` | Inspect the MariaDB container |

First build:

```sh
make up
```

Equivalent Compose command:

```sh
docker compose -f ./srcs/docker-compose.yml up --detach --build
```

Build only:

```sh
make build
```

Recreate containers:

```sh
make down
make up-no-build
```

After changing a Dockerfile or a configuration file copied into an image:

```sh
make down
make build
make up-no-build
```

Clean start:

```sh
make down-v
sudo rm -rf /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
make up
```

## Container and Volume Management Commands

Status:

```sh
docker compose -f srcs/docker-compose.yml ps
docker images
docker network ls
docker volume ls
```

Inspect:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

Shell:

```sh
docker exec --interactive --tty nginx sh
docker exec --interactive --tty wordpress sh
docker exec --interactive --tty mariadb sh
```

Volume inspection:

```sh
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
```

Expected host devices:

```text
/home/tvaroux/data/mariadb
/home/tvaroux/data/wordpress
```

