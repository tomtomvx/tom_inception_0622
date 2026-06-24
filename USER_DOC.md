# USER_DOC.md - Inception User Documentation

This document is for end users or administrators who operate the Inception stack. It also works as a review cheat sheet by summarizing the service roles, start/stop commands, access URLs, credential management, and health checks.

## 1. Services Provided by This Stack

This project starts three containers with Docker Compose and provides a WordPress site over HTTPS.

| Service | Container name | Role | Exposed externally |
|---|---|---|---|
| NGINX | `nginx` | HTTPS entry point. Terminates TLS and forwards PHP requests to WordPress | `443:443` |
| WordPress + PHP-FPM | `wordpress` | WordPress application and PHP runtime. Initial setup is done with `wp-cli` | No |
| MariaDB | `mariadb` | Database that stores WordPress posts, users, comments, and settings | No |

Request flow:

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

Key points:

- Only NGINX port `443` is exposed to the host.
- WordPress and MariaDB communicate through the internal Docker network `network_cake`.
- WordPress files and MariaDB data are persisted under `/home/tvaroux/data/`.
- Passwords are not stored in `.env`; they are mounted as Docker secrets under `/run/secrets/`.

## 2. Starting and Stopping

Run commands from the repository root, where the `Makefile` is located.

```sh
cd /home/tvaroux/Desktop/inception/tom_inception_0622
```

Start:

```sh
make up
```

`make up` runs `docker compose -f ./srcs/docker-compose.yml up --detach --build`. It builds images if needed and starts the containers in the background.

Stop:

```sh
make down
```

This stops and removes the containers. Images, Docker volumes, and host-side data remain.

Stop and remove Docker volumes:

```sh
make down-v
```

This removes Docker volumes too. In this project, however, the volumes are bind-mounted to `/home/tvaroux/data/mariadb` and `/home/tvaroux/data/wordpress`, so check the host-side data as well if you want a full reset.

Restart:

```sh
make re
```

Build only:

```sh
make build
```

Start existing images without rebuilding:

```sh
make up-no-build
```

## 3. Accessing the Website and Admin Panel

Normal website URL:

```text
https://tvaroux.42.fr
```

Local check:

```text
https://127.0.0.1
```

WordPress admin panel:

```text
https://tvaroux.42.fr/wp-admin
```

Local admin check:

```text
https://127.0.0.1/wp-admin
```

The project uses a self-signed certificate, so browsers may show a warning. This is expected for this project.

## 4. Locating and Managing Credentials

Non-secret configuration is stored in `srcs/.env`.

Main settings used by this project:

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

Passwords are managed as files under `secrets/`.

Secret files referenced by Compose:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_editor_password.txt
```

Inside containers, they appear as:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_editor_password
```

Management notes:

- `srcs/.env` stores only non-secret values such as usernames, domain names, and database names.
- Passwords are stored in secret files and must not be committed to Git.
- After the first WordPress install, changing the WordPress password secret does not automatically update existing user passwords. Change them through the admin panel or `wp-cli`.
- If `db_password` is changed while persistent data remains, the existing `wp-config.php` is not updated automatically. It must be updated separately.

## 5. Checking That Services Are Running Correctly

Container status:

```sh
docker compose -f srcs/docker-compose.yml ps
```

Individual checks through the Makefile:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

HTTPS check:

```sh
make curl-https
```

Or:

```sh
curl --insecure --verbose https://127.0.0.1/
```

TLS version check:

```sh
openssl s_client -connect tvaroux.42.fr:443 -tls1_2 </dev/null 2>&1 | grep -E "Protocol|Cipher|CONNECTED"
openssl s_client -connect tvaroux.42.fr:443 -tls1_3 </dev/null 2>&1 | grep -E "Protocol|Cipher|CONNECTED"
```

Logs:

```sh
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

WordPress users:

```sh
docker exec wordpress wp --allow-root --path=/var/www/html user list
```

Check whether MariaDB contains WordPress data:

```sh
docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

Check posts, comments, and users:

```sh
docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SELECT ID, post_title, post_status, post_type FROM wp_posts WHERE post_type = '\''post'\'';"'

docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SELECT comment_ID, comment_author, comment_content, comment_approved FROM wp_comments;"'

docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SELECT ID, user_login, user_email FROM wp_users;"'
```

Review explanation points:

- If `SHOW TABLES;` shows tables such as `wp_posts`, `wp_users`, and `wp_options`, the WordPress database has been initialized.
- After adding a comment or post in the browser, you can confirm the same content through SQL.
- If data remains under `/home/tvaroux/data/`, WordPress content persists even when containers are recreated.
