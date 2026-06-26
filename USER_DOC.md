# USER_DOC - User Operation Guide

This document explains how to use the Inception stack as an end user or
administrator. It is also written as a quick defense note for review.

## Service Overview

This project runs a WordPress website with three Docker containers.

| Service | Role | Access |
| --- | --- | --- |
| `nginx` | Public HTTPS entry point and TLS termination | Host port `443` |
| `wordpress` | WordPress application running through PHP-FPM | Internal port `9000` |
| `mariadb` | Database used by WordPress | Internal port `3306` |

Request flow:

```text
Browser
  -> HTTPS :443
  -> NGINX
  -> FastCGI wordpress:9000
  -> WordPress / PHP-FPM
  -> SQL mariadb:3306
  -> MariaDB
```

Only NGINX is exposed to the host. WordPress and MariaDB stay private inside
the Docker bridge network.

## Start and Stop the Project

Run commands from the repository root:

```sh
cd tom_inception_0622
```

Before the first start, the host data directories must exist:

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

Start the stack:

```sh
make up
```

This builds the images if needed and starts the containers in the background.

Stop the stack but keep persistent data:

```sh
make down
```

Restart the stack:

```sh
make re
```

Start existing images without rebuilding:

```sh
make up-no-build
```

Stop containers and remove Docker Compose volumes:

```sh
make down-v
```

Important: `make down-v` removes Docker volume objects, but the real data is
stored in `/home/tvaroux/data/mariadb` and `/home/tvaroux/data/wordpress`.
Delete those directories only when you really want a clean installation.

## Access the Website and Admin Panel

Main URLs:

```text
https://tvaroux.42.fr
https://127.0.0.1
```

If `tvaroux.42.fr` does not resolve, add this on the VM or evaluation host:

```text
127.0.0.1 tvaroux.42.fr
```

The TLS certificate is self-signed, so the browser may show a warning. This is
expected for this project.

WordPress administration panel:

```text
https://tvaroux.42.fr/wp-admin
https://127.0.0.1/wp-admin
```

The administrator username comes from `srcs/.env`:

```env
WP_ADMIN_USER=ado
```

The editor username comes from `srcs/.env`:

```env
WP_USER=wpeditor
```

The subject forbids using an admin username containing `admin` or `Admin`, so
this project uses a custom admin username.

## Locate and Manage Credentials

Non-secret configuration is stored in:

```text
srcs/.env
```

Create it from the sample:

```sh
cp srcs/.env_sample srcs/.env
```

Current sample values:

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

Passwords are stored as Docker secret files under:

```text
secrets/
```

Create them before starting the stack:

```sh
echo -n pw > secrets/db_password.txt
echo -n pw > secrets/wp_admin_password.txt
echo -n pw > secrets/wp_editor_password.txt
```

Credential mapping:

| Secret file | Used for | Container path |
| --- | --- | --- |
| `secrets/db_password.txt` | MariaDB WordPress user password | `/run/secrets/db_password` |
| `secrets/wp_admin_password.txt` | WordPress admin password | `/run/secrets/wp_admin_password` |
| `secrets/wp_editor_password.txt` | WordPress editor password | `/run/secrets/wp_editor_password` |

Do not commit `srcs/.env` or files inside `secrets/`.

If a password is changed after WordPress has already been installed, existing
WordPress users and `wp-config.php` are not automatically rewritten. For a clean
password reset during evaluation, remove the persistent data and start again.

## Check That Services Are Running

Check container status:

```sh
docker compose -f srcs/docker-compose.yml ps
```

Or use the Makefile shortcuts:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

Check HTTPS from the command line:

```sh
make curl-https
```

Direct TLS check:

```sh
curl -vk https://127.0.0.1/
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```

Expected explanation:

- HTTPS is handled by NGINX.
- Only port `443` is published by Compose.
- TLS versions allowed by NGINX are `TLSv1.2` and `TLSv1.3`.
- The certificate is self-signed.

Check logs:

```sh
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

## WordPress Data Check

To prove the database is initialized and not empty:

```sh
docker exec -it mariadb sh
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
```

Exit with:

```sql
exit;
```

Then leave the container shell:

```sh
exit
```

One-line table check from the host:

```sh
docker exec -it mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

## Persistence Check

Data persists because Docker volumes are bound to host directories:

| Data | Host path | Container path |
| --- | --- | --- |
| MariaDB database files | `/home/tvaroux/data/mariadb` | `/var/lib/mysql` |
| WordPress files | `/home/tvaroux/data/wordpress` | `/var/www/html` |

Review demo:

1. Add a post, page, or comment in WordPress.
2. Run `make down`.
3. Run `make up-no-build`.
4. Open the site again.
5. Confirm the content is still present.
6. Optionally confirm the same content with SQL.

For a completely clean reinstall:

```sh
make down-v
sudo rm -rf /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
make up
```

## Troubleshooting

If the site shows `502 Bad Gateway`, WordPress or PHP-FPM may still be starting.
Wait a few seconds and check:

```sh
docker compose -f srcs/docker-compose.yml logs wordpress
```

If WordPress cannot connect to the database, check:

```sh
docker compose -f srcs/docker-compose.yml ps mariadb
docker compose -f srcs/docker-compose.yml logs mariadb
ls -l secrets/
cat srcs/.env
```

If the browser cannot open `https://tvaroux.42.fr`, use `https://127.0.0.1` or
check `/etc/hosts`.

## レビュー用カンペ

このスタックで提供しているもの:

- WordPress サイトを提供しています。
- 外から直接アクセスできるのは NGINX の HTTPS `443` だけです。
- NGINX は TLS を終端し、PHP は `wordpress:9000` に FastCGI で渡します。
- WordPress は `mariadb:3306` に接続して記事、ユーザー、コメントを保存します。

起動と停止:

```sh
make up      # build して detached 起動
make down    # container 停止と削除、data は保持
make down-v  # compose volume も削除
make re      # down -> up
```

アクセス先:

```text
Site:  https://tvaroux.42.fr または https://127.0.0.1
Admin: https://tvaroux.42.fr/wp-admin
```

認証情報の場所:

- ユーザー名やドメインは `srcs/.env`。
- パスワードは `secrets/*.txt`。
- container 内では `/run/secrets/...` として読まれます。
- secret は Git に入れません。

正常稼働の確認:

```sh
docker compose -f srcs/docker-compose.yml ps
make curl-https
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

永続化の説明:

- DB 実体は `/home/tvaroux/data/mariadb` に残ります。
- WordPress ファイルは `/home/tvaroux/data/wordpress` に残ります。
- container や image を作り直しても、この host 側 data を消さない限りサイト内容は残ります。
