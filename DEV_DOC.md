# DEV_DOC.md - Inception Developer Documentation

This document explains how a developer can set up the Inception environment from scratch, build and launch it with the Makefile and Docker Compose, manage containers and volumes, and explain how persistent data works. It is also written as a review cheat sheet with commands and short oral explanation points.

## 1. Prerequisites

Runtime environment:

- Run inside a VM according to the 42 evaluation requirements
- Docker Engine is available
- Docker Compose v2 is available
- `make`, `curl`, and `openssl` are available
- The bind mount directories can be created under `/home/tvaroux/data/`

Check:

```sh
docker --version
docker compose version
make --version
```

Working directory:

```sh
cd /home/tvaroux/Desktop/inception/tom_inception_0622
```

Main layout:

```text
Makefile
USER_DOC.md
DEV_DOC.md
srcs/
  docker-compose.yml
  .env
  requirements/
    mariadb/
      Dockerfile
      conf/zzz-mariadb.cnf
      tools/entrypoint.sh
    wordpress/
      Dockerfile
      conf/www.conf
      tools/entrypoint.sh
    nginx/
      Dockerfile
      conf/zzz-nginx.conf
secrets/
```

## 2. Setting Up from Scratch

### 2-1. Host Data Directories

The Compose volumes are bind-mounted to real directories on the host, not only to Docker-managed storage.

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

Meaning:

- `/home/tvaroux/data/mariadb` stores the actual MariaDB database files.
- `/home/tvaroux/data/wordpress` stores WordPress PHP files, uploads, configuration files, and related data.
- If these directories remain, the data remains even after containers are removed.

### 2-2. `.env`

Write non-secret configuration in `srcs/.env`.

Example:

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

Notes:

- Do not use names such as `admin` or `administrator` for `WP_ADMIN_USER`, because such names are commonly forbidden by the subject.
- This WordPress entrypoint reads `WP_USER` and `WP_USER_EMAIL` for the editor user.
- Passwords are not stored in `.env`.

### 2-3. Secrets

Create password files under `secrets/`.

```sh
mkdir -p secrets
printf 'db_password_here\n' > secrets/db_password.txt
printf 'db_root_password_here\n' > secrets/db_root_password.txt
printf 'wp_admin_password_here\n' > secrets/wp_admin_password.txt
printf 'wp_editor_password_here\n' > secrets/wp_editor_password.txt
```

Compose definition:

```yaml
secrets:
  db_password:
    file: ../secrets/db_password.txt
  db_root_password:
    file: ../secrets/db_root_password.txt
  wp_admin_password:
    file: ../secrets/wp_admin_password.txt
  wp_editor_password:
    file: ../secrets/wp_editor_password.txt
```

Inside containers:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_editor_password
```

Review explanation:

- `.env` is for configuration, secrets are for passwords.
- Secrets are mounted as files, not exposed as process environment variables.
- They are used to avoid committing passwords to Git.

## 3. Building and Launching

The Makefile uses:

```make
DC = docker compose -f ./srcs/docker-compose.yml
```

Start:

```sh
make up
```

Equivalent command:

```sh
docker compose -f ./srcs/docker-compose.yml up --detach --build
```

Build only:

```sh
make build
```

Start with existing images:

```sh
make up-no-build
```

Stop:

```sh
make down
```

Remove containers and Docker volumes:

```sh
make down-v
```

Restart:

```sh
make re
```

Validate Compose configuration:

```sh
docker compose -f srcs/docker-compose.yml config
```

## 4. Docker Compose Structure

Services:

| Service | image | build context | container_name | restart |
|---|---|---|---|---|
| `mariadb` | `mariadb:banana` | `./requirements/mariadb` | `mariadb` | `always` |
| `wordpress` | `wordpress:peach` | `./requirements/wordpress` | `wordpress` | `always` |
| `nginx` | `nginx:apple` | `./requirements/nginx` | `nginx` | `always` |

Network:

```yaml
networks:
  network_cake:
    driver: bridge
```

Oral explanation:

- `network_cake` is a dedicated bridge network.
- Containers can resolve each other by service name.
- NGINX forwards FastCGI requests to `wordpress:9000`.
- WordPress connects to `mariadb:3306` with SQL.
- The project does not use `network: host` or `links`.

Exposed port:

```yaml
nginx:
  ports:
    - "443:443"
```

Oral explanation:

- The only host-visible entry point is HTTPS port `443`.
- MariaDB and WordPress are not exposed externally.

## 5. Implementation Points for Each Container

### 5-1. MariaDB

Dockerfile:

- Base image is `alpine:3.23`
- Installs `mariadb` and `mariadb-client`
- Uses `/var/lib/mysql` as the data directory
- Copies `conf/zzz-mariadb.cnf`
- Runs `tools/entrypoint.sh` as PID 1

Configuration:

```ini
bind-address = 0.0.0.0
port = 3306
skip-networking = 0
```

Entrypoint flow:

1. If `/var/lib/mysql/mysql` does not exist, treat it as the first initialization.
2. Run `mariadb-install-db` to create the system database.
3. Temporarily start the server with `mariadbd --user=mysql --skip-networking &`.
4. Wait for startup with `mariadb-admin ping`.
5. Read `/run/secrets/db_password` and create the WordPress database and user.
6. Stop the temporary server with `mariadb-admin shutdown`.
7. Finally, run the production server with `exec mariadbd --user=mysql`.

Meaning of the initialization SQL:

```sql
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY '...';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
FLUSH PRIVILEGES;
```

Explanation points:

- Initialization happens only on the first run, so existing data is not destroyed on restart.
- `wpuser@'%'` is the user used for TCP connections from other containers.
- The production process uses `exec`, becomes PID 1, and can receive container signals.

### 5-2. WordPress

Dockerfile:

- Base image is `alpine:3.23`
- Installs `php83`, `php83-fpm`, `php83-mysqli`, and related packages
- Installs `wp-cli.phar` as `/usr/local/bin/wp`
- Copies the PHP-FPM configuration `www.conf`
- Starts `tools/entrypoint.sh`

PHP-FPM:

```ini
listen = 9000
```

Entrypoint flow:

1. Read `/run/secrets/db_password`.
2. Wait for the database with `mariadb-admin ping --host=mariadb --port=3306`.
3. If `/var/www/html/wp-settings.php` does not exist, run `wp core download`.
4. If `wp-config.php` does not exist, create it with the database connection settings.
5. If `wp core is-installed` is false, install WordPress.
6. Create the administrator `WP_ADMIN_USER` and editor `WP_USER`.
7. Start PHP-FPM in the foreground with `exec php-fpm83 -F`.

Explanation points:

- The WordPress container does not contain NGINX.
- The web server and PHP runtime are separated.
- `wp-cli` is used for WordPress initialization and user creation.
- `php-fpm83 -F` prevents daemonization and keeps PHP-FPM as the main container process.

### 5-3. NGINX

Dockerfile:

- Base image is `alpine:3.23`
- Installs `nginx` and `openssl`
- Creates a self-signed certificate under `/etc/nginx/ssl/`
- Copies `conf/zzz-nginx.conf` to `/etc/nginx/nginx.conf`
- Starts NGINX in the foreground with `nginx -g "daemon off;"`

Configuration:

```nginx
listen 443 ssl;
server_name tvaroux.42.fr;
ssl_protocols TLSv1.2 TLSv1.3;
root /var/www/html;

location ~ \.php$ {
    fastcgi_pass wordpress:9000;
}
```

Explanation points:

- NGINX handles TLS termination.
- `ssl_protocols TLSv1.2 TLSv1.3;` limits HTTPS to TLS 1.2 or newer.
- NGINX does not process PHP itself; it forwards PHP requests to PHP-FPM at `wordpress:9000`.
- `daemon off;` keeps NGINX as the main PID 1 process.

## 6. Commands for Managing Containers, Images, and Volumes

Status:

```sh
docker compose -f srcs/docker-compose.yml ps
docker ps
```

Logs:

```sh
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

Images:

```sh
docker images | grep -E 'mariadb|wordpress|nginx'
```

Network:

```sh
docker network ls | grep network_cake
docker network inspect srcs_network_cake
```

Volumes:

```sh
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
```

Enter containers:

```sh
docker exec --interactive --tty mariadb sh
docker exec --interactive --tty wordpress sh
docker exec --interactive --tty nginx sh
```

Makefile inspect targets:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

## 7. Data Storage and Persistence

Compose volumes:

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

Storage locations:

| Data | Inside container | Host side |
|---|---|---|
| MariaDB DB files | `/var/lib/mysql` | `/home/tvaroux/data/mariadb` |
| WordPress files | `/var/www/html` | `/home/tvaroux/data/wordpress` |

Persistence explanation:

- Docker volume names include the Compose project name, for example `srcs_mariadb_data`.
- The real storage is not only Docker's internal volume directory; it is bind-mounted to `/home/tvaroux/data/...`.
- If the host-side directories remain, database and WordPress files remain even after containers are removed.
- To fully reset the project, run `make down-v` and also delete the contents of `/home/tvaroux/data/mariadb` and `/home/tvaroux/data/wordpress`.

Persistence demo:

```sh
# 1. Add a post or comment from the WordPress admin panel
# 2. Stop the containers
make down

# 3. Start again
make up-no-build

# 4. Confirm that the added content remains through the browser or SQL
```

SQL check:

```sh
docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SELECT ID, post_title, post_status, post_type FROM wp_posts WHERE post_type = '\''post'\'';"'
```

## 8. Review Check Commands

Forbidden-item checks:

```sh
grep -rnE 'network:\s*host|links:|--link' srcs Makefile || echo "OK: no forbidden network setting"
grep -rnE 'tail -f|sleep infinity|/dev/null|/dev/random|& *bash|& *sh' srcs/requirements/*/Dockerfile srcs/requirements/*/tools || echo "OK: no fake daemon keepalive"
grep -n '^FROM' srcs/requirements/*/Dockerfile
```

Compose status:

```sh
docker compose -f srcs/docker-compose.yml ps
```

HTTPS:

```sh
curl --insecure --verbose https://127.0.0.1/
openssl s_client -connect tvaroux.42.fr:443 -tls1_2 </dev/null 2>&1 | grep -E "Protocol|Cipher|CONNECTED"
openssl s_client -connect tvaroux.42.fr:443 -tls1_3 </dev/null 2>&1 | grep -E "Protocol|Cipher|CONNECTED"
```

WordPress:

```sh
docker exec wordpress wp --allow-root --path=/var/www/html user list
docker exec wordpress wp --allow-root --path=/var/www/html option get siteurl
```

MariaDB:

```sh
docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'

docker exec --interactive --tty mariadb sh -c \
  'mariadb -u root -e "SELECT User, Host, plugin FROM mysql.user;"'
```

Volumes:

```sh
docker volume inspect srcs_mariadb_data --format '{{ .Options.device }}'
docker volume inspect srcs_wordpress_data --format '{{ .Options.device }}'
```

## 9. Common Problems and Explanations

### Secrets Cannot Be Found

Symptom:

```text
cat: can't open '/run/secrets/db_password': No such file or directory
```

Causes:

- The secret file does not exist.
- The filename differs from the Compose definition.
- The container was started with raw `docker run` instead of Compose, and the secret was not mounted.

Checks:

```sh
ls -l secrets/
docker compose -f srcs/docker-compose.yml config
```

### WordPress Cannot Connect to the Database

Check:

```sh
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

Explanation:

- WordPress connects to `mariadb:3306`.
- It does not connect to `localhost`. Inside a container, `localhost` means the WordPress container itself.
- The MariaDB user is created as `'wpuser'@'%'`, which allows TCP connections from other containers.

### `wpuser@localhost` Is Rejected

Example:

```text
ERROR 1045 (28000): Access denied for user 'wpuser'@'localhost'
```

Explanation:

- `wpuser` is created as `wpuser@'%'`.
- If you connect from inside a container using `localhost`, MariaDB may treat it as a UNIX socket or local connection and match a different account.
- WordPress uses the `mariadb` host name over TCP, so this is not a problem for the application.

## 10. Short Oral Summary

This project separates NGINX, WordPress/PHP-FPM, and MariaDB into one container per service, then manages networks, secrets, and volumes with Docker Compose. The only external entry point is NGINX HTTPS on port `443`; WordPress runs as PHP-FPM on `9000`, and MariaDB is used internally on `3306`. Data is bind-mounted to `/home/tvaroux/data/mariadb` and `/home/tvaroux/data/wordpress`, so it persists even if containers are recreated. Passwords are not committed to Git; they are read from Docker secrets mounted under `/run/secrets/`.
