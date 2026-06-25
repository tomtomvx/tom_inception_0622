# DEV_DOC - Developer Documentation

This document explains how to set up, build, run, inspect, and defend this
Inception project from a developer point of view.

## Project Layout

```text
.
|-- Makefile
|-- README.md
|-- README-jp.md
|-- USER_DOC.md
|-- DEV_DOC.md
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

Each service has its own Dockerfile, configuration, and startup logic. The full
stack is declared in `srcs/docker-compose.yml`.

## Environment Setup From Scratch

Run all project commands from:

```sh
cd tom_inception_0622
```

Required tools:

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

### 1. Prepare persistent host directories

The Compose volumes use the local driver with bind options. These host
directories must exist before startup:

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

MariaDB files are persisted in `/home/tvaroux/data/mariadb`.
WordPress files are persisted in `/home/tvaroux/data/wordpress`.

### 2. Create `srcs/.env`

```sh
cp srcs/.env_sample srcs/.env
```

Sample values:

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

Use `.env` for non-secret configuration. Do not put passwords in `.env`.

Important defense point: the WordPress administrator username must not contain
`admin` or `Admin`.

### 3. Create Docker secrets

The Compose file expects four host files:

```sh
mkdir -p secrets
printf '%s' 'database_user_password' > secrets/db_password.txt
printf '%s' 'database_root_password' > secrets/db_root_password.txt
printf '%s' 'wordpress_admin_password' > secrets/wp_admin_password.txt
printf '%s' 'wordpress_editor_password' > secrets/wp_editor_password.txt
```

Compose maps them to secret names:

| Compose secret | Host file | Runtime path |
| --- | --- | --- |
| `db_password` | `../secrets/db_password.txt` | `/run/secrets/db_password` |
| `db_root_password` | `../secrets/db_root_password.txt` | `/run/secrets/db_root_password` |
| `wp_admin_password` | `../secrets/wp_admin_password.txt` | `/run/secrets/wp_admin_password` |
| `wp_editor_password` | `../secrets/wp_editor_password.txt` | `/run/secrets/wp_editor_password` |

Passwords are read by entrypoint scripts as files. This avoids exposing secrets
as normal environment variables.

### 4. Optional domain setup

If the domain is not already resolvable:

```text
127.0.0.1 tvaroux.42.fr
```

Add it to `/etc/hosts` on the VM or evaluation host.

## Build and Launch

Main Makefile targets:

| Target | Purpose |
| --- | --- |
| `make` / `make all` / `make up` | Build images and start containers detached |
| `make build` | Build images only |
| `make up-no-build` | Start existing images without rebuilding |
| `make down` | Stop and remove containers |
| `make down-v` | Stop containers and remove Compose volumes |
| `make re` | Run `make down` then `make up` |
| `make curl-https` | Test HTTPS with `curl --insecure --verbose` |
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

Rebuild after Dockerfile or copied configuration changes:

```sh
make down
make build
make up-no-build
```

Note: the current `fclean` and `rebuild` targets in the Makefile remove
`/home/tvaroux/data/...`. For this repository version, the Compose volumes use
`/home/tvaroux/data/...`, so use the manual clean commands below unless the
Makefile path is corrected.

Clean start:

```sh
make down-v
sudo rm -rf /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
make up
```

## Docker Compose Design

Services:

| Service | Container | Image tag | Build context |
| --- | --- | --- | --- |
| `mariadb` | `mariadb` | `mariadb:banana` | `srcs/requirements/mariadb` |
| `wordpress` | `wordpress` | `wordpress:peach` | `srcs/requirements/wordpress` |
| `nginx` | `nginx` | `nginx:apple` | `srcs/requirements/nginx` |

Network:

```yaml
networks:
  network_cake:
    driver: bridge
```

Docker may display the network with a Compose project prefix, for example
`srcs_network_cake`.

Only NGINX publishes a port:

```yaml
ports:
  - "443:443"
```

WordPress and MariaDB are reachable only inside the Docker network:

- NGINX -> `wordpress:9000`
- WordPress -> `mariadb:3306`

## Service Startup Flow

### NGINX

Files:

- `srcs/requirements/nginx/Dockerfile`
- `srcs/requirements/nginx/conf/zzz-nginx.conf`

Key points:

- Base image: `alpine:3.23`
- Runtime packages: `nginx`, `openssl`
- Self-signed certificate generated during image build
- Certificate path: `/etc/nginx/ssl/tvaroux_server.crt`
- Key path: `/etc/nginx/ssl/tvaroux_server.key`
- Listens on `443 ssl`
- Allows `TLSv1.2 TLSv1.3`
- Forwards PHP requests to `wordpress:9000`
- Runs in foreground with `nginx -g 'daemon off;'`

Defense explanation: NGINX is the only public entry point. It terminates TLS
and passes PHP requests to PHP-FPM over FastCGI.

### WordPress / PHP-FPM

Files:

- `srcs/requirements/wordpress/Dockerfile`
- `srcs/requirements/wordpress/conf/www.conf`
- `srcs/requirements/wordpress/tools/entrypoint.sh`

Key points:

- Base image: `alpine:3.23`
- Runtime packages include `php83`, `php83-fpm`, `php83-mysqli`, `php83-curl`,
  `php83-xml`, `php83-dom`, and `php83-mbstring`
- WP-CLI is installed as `/usr/local/bin/wp`
- Working directory: `/var/www/html`
- PHP-FPM listens on `9000`
- Runs in foreground with `exec php-fpm83 -F`

Startup flow:

1. Read DB password from `/run/secrets/db_password`.
2. Wait until MariaDB accepts authenticated ping on `mariadb:${MARIADB_PORT:-3306}`.
3. Download WordPress core if `/var/www/html/wp-settings.php` does not exist.
4. Create `wp-config.php` if it does not exist.
5. Run `wp core install` if WordPress is not installed.
6. Create the editor user.
7. Start PHP-FPM as PID 1.

Important: `wp-config.php` and existing WordPress users are not automatically
updated if secrets change later. For a clean reset, clear persistent data and
start again.

### MariaDB

Files:

- `srcs/requirements/mariadb/Dockerfile`
- `srcs/requirements/mariadb/conf/zzz-mariadb.cnf`
- `srcs/requirements/mariadb/tools/entrypoint.sh`

Key points:

- Base image: `alpine:3.23`
- Runtime packages: `mariadb`, `mariadb-client`
- Data directory: `/var/lib/mysql`
- Binds to `0.0.0.0`
- Listens on `3306`
- Runs in foreground with `exec mariadbd --user=mysql`

First-start flow:

1. Check whether `/var/lib/mysql/mysql` exists.
2. If missing, run `mariadb-install-db`.
3. Start temporary MariaDB with `--skip-networking`.
4. Wait for `mariadb-admin ping`.
5. Read app DB password from `/run/secrets/db_password`.
6. Remove anonymous users.
7. Remove the default `test` database.
8. Create `${MARIADB_DATABASE}`.
9. Create `${MARIADB_USER}` for host `%`.
10. Grant privileges on `${MARIADB_DATABASE}.*`.
11. Stop the temporary server.
12. Start the real MariaDB server as PID 1.

The initialization guard prevents existing database data from being overwritten
on container restart.

## Container and Volume Management Commands

Status:

```sh
docker compose -f srcs/docker-compose.yml ps
docker images | grep -E 'mariadb|wordpress|nginx'
docker network ls
docker volume ls
```

Inspect:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

Logs:

```sh
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

Shell:

```sh
docker exec -it nginx sh
docker exec -it wordpress sh
docker exec -it mariadb sh
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

## Data Persistence

Compose volume definition:

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

Persistence summary:

| Data | Host path | Container path |
| --- | --- | --- |
| MariaDB database | `/home/tvaroux/data/mariadb` | `/var/lib/mysql` |
| WordPress files | `/home/tvaroux/data/wordpress` | `/var/www/html` |

Why this persists:

- Containers are disposable.
- The data directories are mounted from the host.
- Rebuilding images or recreating containers does not delete the host paths.
- `restart: always` allows containers to restart after Docker or VM restart.

Review demo:

```sh
make down
make up-no-build
curl -vk https://127.0.0.1/
```

Then show the edited WordPress content still exists.

## Verification and Defense Commands

### General checks

```sh
docker compose -f srcs/docker-compose.yml ps
docker images | grep -E 'mariadb|wordpress|nginx'
docker network ls | grep network_cake
docker volume ls
```

### Forbidden pattern checks

```sh
grep -rnE 'network:\s*host|links:|--link' srcs Makefile || echo "OK: no forbidden network shortcut"
grep -rnE 'tail -f|sleep infinity|/dev/null|/dev/random|& *bash|& *sh' srcs/requirements/*/Dockerfile srcs/requirements/*/tools || echo "OK: no fake keepalive"
grep -n '^FROM' srcs/requirements/*/Dockerfile
```

Defense explanation: containers stay alive because the real service process runs
in the foreground. They are not kept alive by fake loops.

Foreground commands:

- NGINX: `nginx -g 'daemon off;'`
- WordPress: `exec php-fpm83 -F`
- MariaDB: `exec mariadbd --user=mysql`

### TLS checks

```sh
curl -vk https://127.0.0.1/
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```

Explain:

- NGINX handles HTTPS.
- `ssl_protocols TLSv1.2 TLSv1.3;` is configured.
- The certificate is self-signed for this local project.
- Only `443:443` is published.

### SQL checks

Enter MariaDB:

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

One-line check:

```sh
docker exec -it mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

This proves that WordPress initialized the database and that real site data is
stored in MariaDB.

### Backup and restore

Backup:

```sh
docker compose -f srcs/docker-compose.yml exec mariadb sh -c 'mariadb-dump -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE"' > backup.sql
```

Restore:

```sh
docker compose -f srcs/docker-compose.yml exec -T mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE"' < backup.sql
```

## Configuration Change Example

If the evaluator asks to change the public HTTPS port, change only the host side
of the mapping:

```yaml
ports:
  - "8443:443"
```

Then recreate containers:

```sh
make down
make up-no-build
curl -vk https://127.0.0.1:8443/
```

If the NGINX listening port inside the container is changed, update both
`zzz-nginx.conf` and the Compose mapping, then rebuild because the config is
copied into the image:

```sh
make down
make build
make up-no-build
```

## Clean Evaluation Start

The evaluator may ask to start from a clean Docker state. These commands are
usually run manually, not from the project Makefile:

```sh
docker stop $(docker ps -qa)
docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
sudo rm -rf /home/tvaroux/data/*
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
```

Then recreate:

```sh
cp srcs/.env_sample srcs/.env
mkdir -p secrets
printf '%s' 'database_user_password' > secrets/db_password.txt
printf '%s' 'database_root_password' > secrets/db_root_password.txt
printf '%s' 'wordpress_admin_password' > secrets/wp_admin_password.txt
printf '%s' 'wordpress_editor_password' > secrets/wp_editor_password.txt
make up
```

## Quick Oral Defense Notes

- Docker packages each service and its dependencies into a reproducible image.
- Compose connects services, secrets, volumes, and network in one file.
- A VM virtualizes a whole OS; Docker isolates processes while sharing the host
  kernel.
- Secrets are mounted as files in `/run/secrets/`; `.env` is for non-secret
  configuration.
- `network_cake` is a bridge network; host network mode is not used.
- Service names provide DNS: `wordpress` and `mariadb`.
- Only NGINX exposes a host port.
- Volumes persist data under `/home/tvaroux/data/...`.
- PID 1 is the real service process, so containers stop and receive signals
  correctly.
- MariaDB initialization is guarded by `/var/lib/mysql/mysql`, so restarts do
  not overwrite data.
- WordPress initialization is guarded by existing core/config/install state.

## レビュー用カンペ

### 何を作ったか

Docker Compose で WordPress サイトを構築しました。構成は `nginx`、
`wordpress`、`mariadb` の 3 コンテナです。外部公開は NGINX の `443`
だけで、WordPress と MariaDB は Docker bridge network の中だけで通信します。

### Docker と VM の違い

VM は OS 丸ごとを仮想化します。Docker は host kernel を共有し、process と
filesystem と network を分離します。そのため Docker container は軽く、build
した image から同じ runtime を再現しやすいです。

### Compose を使う理由

`docker run` だけだと network、volume、secret、依存関係を毎回手で指定する必要があります。
Compose なら `srcs/docker-compose.yml` に 3 service、network、volume、secret をまとめて宣言できます。

### Secrets と `.env`

`.env` は `DOMAIN_NAME`、DB 名、ユーザー名のような非機密設定です。password は
`secrets/*.txt` に置き、container 内では `/run/secrets/...` の file として読みます。
password を environment variable に置くより、`docker inspect` や process environment に出にくい設計です。

### Network

`network_cake` は bridge network です。host network は使っていません。Docker DNS
により、NGINX は `wordpress:9000`、WordPress は `mariadb:3306` で接続できます。

### Volume と永続化

Compose volume は local driver の bind option で host directory に結びつけています。

```text
/home/tvaroux/data/mariadb    -> /var/lib/mysql
/home/tvaroux/data/wordpress  -> /var/www/html
```

container は disposable ですが、data は host 側に残るため、`make down` や rebuild 後も
WordPress の記事、コメント、DB table は残ります。

### PID 1 と foreground

container は PID 1 の process が終了すると止まります。この project は fake keepalive
ではなく、本物の service を foreground で動かしています。

```text
nginx      -> nginx -g 'daemon off;'
wordpress  -> exec php-fpm83 -F
mariadb    -> exec mariadbd --user=mysql
```

`exec` を使うことで shell ではなく service process が PID 1 になり、stop signal を受け取れます。

### MariaDB 初期化

`/var/lib/mysql/mysql` がない初回だけ `mariadb-install-db` します。その後 temporary
server を `--skip-networking` で起動し、DB と user を作って権限を付与します。最後に temporary
server を止め、本番の `mariadbd` を foreground で起動します。

### WordPress 初期化

WordPress は MariaDB が認証付き ping に応答するまで待ちます。その後、core download、
`wp-config.php` 作成、`wp core install`、editor user 作成を初回だけ行い、最後に
PHP-FPM を foreground で起動します。

### 評価で即出せる確認コマンド

```sh
docker compose -f srcs/docker-compose.yml ps
docker images | grep -E 'mariadb|wordpress|nginx'
docker network ls | grep network_cake
docker volume ls
make curl-https
```

SQL で WordPress data を見る:

```sh
docker exec -it mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

TLS を見る:

```sh
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```
