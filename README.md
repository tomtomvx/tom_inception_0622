*This project has been created as part of the 42 curriculum by tvaroux.*

# Inception

## Description

Inception is a 42 system administration project. Its goal is to build a small
web infrastructure with Docker and Docker Compose, using custom images and clear
service separation.

This project runs a WordPress website with three containers:

- `nginx`: the only public entry point, exposed on HTTPS port `443`
- `wordpress`: WordPress served by PHP-FPM on the internal port `9000`
- `mariadb`: the database server used by WordPress on the internal port `3306`

The stack is declared in `srcs/docker-compose.yml`. Each service has its own
Dockerfile, configuration, and startup script under
`srcs/requirements/<service>/`.


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
│  │                 tvaroux_network (bridge)             │  │
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
│            /home/tvaroux/data/wordpress                    │
│            /home/tvaroux/data/mariadb                      │
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

Docker is used to isolate services, keep the runtime reproducible, and make the
infrastructure easy to rebuild from source. Docker Compose connects the services
with a dedicated bridge network, mounts persistent data volumes, injects
non-secret configuration through `.env`, and injects passwords through Docker
secrets.

## Instructions

Run commands from the project root:

```sh
cd tom_inception_0622
```

Docker Engine and Docker Compose must be installed.

### 1. Prepare host data directories

The Compose volumes bind to host directories, so create them before starting the
stack:

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

These paths are used by `driver_opts.device` in `srcs/docker-compose.yml`.

### 2. Create `.env`

Create `srcs/.env` from the sample file:

```sh
cp srcs/.env_sample srcs/.env
```

Example values:

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

The administrator username must not contain `admin` or `Admin`.

If needed, add the domain to `/etc/hosts` on the VM or evaluation host:

```text
127.0.0.1 tvaroux.42.fr
```

### 3. Create Docker secret files

Create the secret files expected by Compose:

```sh
mkdir -p secrets
printf 'database_user_password\n' > secrets/db_password.txt
printf 'database_root_password\n' > secrets/db_root_password.txt
printf 'wordpress_admin_password\n' > secrets/wp_admin_password.txt
printf 'wordpress_editor_password\n' > secrets/wp_editor_password.txt
```

These files contain credentials and must not be committed to Git.

### 4. Build and run

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
```

The TLS certificate is self-signed, so a browser warning is expected.

### Useful Make targets

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

## Services

### NGINX

The NGINX image is built from `srcs/requirements/nginx/Dockerfile`.

Important points:

- Base image: `alpine:3.23`
- Runtime packages: `nginx`, `openssl`
- Image tag: `nginx:apple`
- Configuration file: `srcs/requirements/nginx/conf/zzz-nginx.conf`
- A self-signed certificate is generated during image build
- HTTPS listens on `443 ssl`
- TLS is restricted to `TLSv1.2 TLSv1.3`
- PHP requests are forwarded to `wordpress:9000` through FastCGI
- NGINX stays in the foreground with `nginx -g 'daemon off;'`

Only NGINX publishes a host port:

```yaml
ports:
  - "443:443"
```

WordPress and MariaDB are not directly exposed to the host.

### WordPress / PHP-FPM

The WordPress image is built from `srcs/requirements/wordpress/Dockerfile`.

Important points:

- Base image: `alpine:3.23`
- Runtime packages include `php83`, `php83-fpm`, `php83-mysqli`,
  `php83-curl`, XML, DOM, and mbstring modules
- Image tag: `wordpress:peach`
- WP-CLI is installed as `/usr/local/bin/wp`
- PHP-FPM listens on port `9000`
- WordPress files are stored in `/var/www/html`
- The container waits for MariaDB before installing WordPress
- Passwords are read from `/run/secrets/`
- PHP-FPM stays in the foreground with `exec php-fpm83 -F`

On first start, `tools/entrypoint.sh`:

1. Reads the database password from `/run/secrets/db_password`.
2. Waits until `mariadb` answers on `${MARIADB_PORT:-3306}`.
3. Downloads WordPress core if `/var/www/html/wp-settings.php` does not exist.
4. Creates `wp-config.php` if it does not exist.
5. Runs `wp core install` if WordPress is not installed.
6. Creates one administrator user and one editor user.
7. Starts PHP-FPM as PID 1.

### MariaDB

The MariaDB image is built from `srcs/requirements/mariadb/Dockerfile`.

Important points:

- Base image: `alpine:3.23`
- Runtime packages: `mariadb`, `mariadb-client`
- Image tag: `mariadb:banana`
- Configuration file: `srcs/requirements/mariadb/conf/zzz-mariadb.cnf`
- MariaDB binds to `0.0.0.0` inside the Docker network
- MariaDB listens on port `3306`
- Database files are stored in `/var/lib/mysql`
- The service starts with `exec mariadbd --user=mysql`

On first start, `tools/entrypoint.sh`:

1. Checks whether `/var/lib/mysql/mysql` exists.
2. If not, initializes the data directory with `mariadb-install-db`.
3. Starts a temporary MariaDB server with `--skip-networking`.
4. Waits for `mariadb-admin ping`.
5. Reads the application database password from `/run/secrets/db_password`.
6. Removes anonymous users and the default `test` database.
7. Creates the WordPress database.
8. Creates `${MARIADB_USER}` for host `%`.
9. Grants privileges on `${MARIADB_DATABASE}.*`.
10. Shuts down the temporary server.
11. Starts the real MariaDB server as PID 1.

The init guard prevents existing database data from being overwritten on
container restart.

## Main Design Choices

### Virtual Machines vs Docker

| Point | Virtual Machine | Docker Container |
| --- | --- | --- |
| Virtualization level | Hardware-level virtualization | OS-level process isolation |
| Kernel | Runs a full guest OS and kernel | Shares the host kernel |
| Startup | Usually slower | Usually faster |
| Resource usage | Heavier | Lighter |
| Best use | Full OS isolation | Packaging one service and its dependencies |

The subject expects the project to run in a virtualized environment, so Docker
may run inside a VM during evaluation. Inside that VM, Docker containers are a
better fit than installing NGINX, PHP-FPM, and MariaDB directly on the machine:
each service can be built, started, stopped, inspected, and rebuilt
independently.

### Secrets vs Environment Variables

| Point | Docker secrets | Environment variables |
| --- | --- | --- |
| Best use | Passwords and credentials | Non-sensitive configuration |
| Exposure | Mounted as files in `/run/secrets/` | Visible in process environments and inspect output |
| In this project | DB and WordPress passwords | Domain, database name, usernames |

The Compose file declares these Docker secrets:

- `db_password`
- `db_root_password`
- `wp_admin_password`
- `wp_editor_password`

The runtime scripts read secrets as files, for example:

```sh
cat /run/secrets/db_password
```

Environment variables are used for useful non-secret configuration such as
`DOMAIN_NAME`, `MARIADB_DATABASE`, `MARIADB_USER`, `WP_ADMIN_USER`, and
`WP_USER`.

### Docker Network vs Host Network

| Point | Docker bridge network | Host network |
| --- | --- | --- |
| Isolation | Services stay in a private Docker network | Containers share the host network namespace |
| Service discovery | Service names resolve through Docker DNS | No Compose service-name isolation |
| Port exposure | Only selected ports are published | Services can bind directly to host ports |
| In this project | `network_cake` | Not used |

The stack uses a dedicated bridge network declared as `network_cake`. Compose
usually creates it with a project prefix, so Docker may display it as
`srcs_network_cake`.

This allows:

- NGINX to reach WordPress as `wordpress:9000`
- WordPress to reach MariaDB as `mariadb:3306`
- MariaDB to stay private and unexposed to the host

Only port `443` is published.

### Docker Volumes vs Bind Mounts

| Point | Docker volume | Bind mount |
| --- | --- | --- |
| Managed by | Docker | Host filesystem path |
| Portability | Less tied to a fixed host path | Depends directly on host paths |
| Visibility | Managed through Docker commands | Visible directly on the host |
| In this project | Compose volumes with local driver | `driver_opts` binds to `/home/tvaroux/data/...` |

This project defines Docker volumes and uses the local driver's bind options:

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

The result is:

- MariaDB data persists under `/home/tvaroux/data/mariadb`
- WordPress files persist under `/home/tvaroux/data/wordpress`
- Rebuilding or recreating containers does not erase site data

## Defense Notes

### Clean evaluation start

The evaluator may ask for a clean Docker state before building:

```sh
docker stop $(docker ps -qa)
docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
sudo rm -rf /home/tvaroux/data/*
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
```

Then recreate `srcs/.env` and the `secrets/*.txt` files, and run:

```sh
make up
```

### Quick health checks

```sh
docker compose -f srcs/docker-compose.yml ps
docker network ls
docker volume ls
docker images | grep -E 'mariadb|wordpress|nginx'
```

Expected containers:

```text
mariadb
wordpress
nginx
```

Expected image tags:

```text
mariadb:banana
wordpress:peach
nginx:apple
```

Expected network:

```text
srcs_network_cake
```

### TLS checks

```sh
curl -vk https://127.0.0.1/
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```

Explain:

- HTTPS is terminated by NGINX.
- The certificate is self-signed.
- The NGINX config allows TLS 1.2 and TLS 1.3.
- Compose publishes only `443:443`.

### SQL checks

Enter the MariaDB container:

```sh
docker exec -it mariadb sh
```

Connect to the WordPress database:

```sh
mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE"
```

Useful SQL:

```sql
SHOW TABLES;

SELECT ID, post_title, post_status, post_type
FROM wp_posts
WHERE post_type = 'post';

SELECT comment_ID, comment_author, comment_content, comment_approved
FROM wp_comments;

SELECT ID, user_login, user_email
FROM wp_users;

SELECT option_name, option_value
FROM wp_options
WHERE option_name IN ('siteurl', 'home', 'blogname');
```

One-line table check from the host:

```sh
docker exec -it mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

This proves that WordPress has initialized the database and that real site data
is stored in MariaDB.

### Persistence checks

1. Add or edit content in WordPress.
2. Run `make down`.
3. Run `make up-no-build`.
4. Open the site again and check that the content still exists.
5. Confirm the same content through SQL.

Persistence works because the database and WordPress files are stored in
host-backed volumes, not only inside disposable containers.

### Configuration change example

If asked to change the public HTTPS port, change the host side of the mapping:

```yaml
ports:
  - "8443:443"
```

Then recreate the containers:

```sh
make down
make up-no-build
curl -vk https://127.0.0.1:8443/
```

If a file copied into an image changes, such as an NGINX config file or
Dockerfile, rebuild the affected image before starting again:

```sh
make down
make build
make up-no-build
```

### Forbidden patterns to explain

The containers stay alive because their real service runs in the foreground,
not because of fake commands such as `tail -f`, `sleep infinity`, or an infinite
loop.

In this project:

- NGINX uses `nginx -g 'daemon off;'`
- WordPress uses `exec php-fpm83 -F`
- MariaDB uses `exec mariadbd --user=mysql`

This matters because the service process becomes PID 1 and receives container
lifecycle signals correctly.

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
- GNU Make manual: https://www.gnu.org/software/make/manual/make.html
- VirtualBox manual: https://www.virtualbox.org/manual/UserManual.html
- RFC 8446, TLS 1.3: https://datatracker.ietf.org/doc/html/rfc8446

### AI usage

AI was used as a learning and documentation assistant during this project.

It helped with:

- Explaining Docker concepts such as images, containers, volumes, networks, and
  secrets
- Comparing virtual machines and Docker containers
- Reviewing Docker Compose design choices
- Understanding NGINX, FastCGI, PHP-FPM, MariaDB initialization, and WP-CLI
  workflows
- Preparing verification commands and SQL checks for the defense
- Structuring this README and related study notes

AI was not used as a substitute for understanding the project. The final design
decisions, implementation, debugging, testing, and defense explanations were
checked and owned by the student.
