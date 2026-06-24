# DEV_DOC.md - Inception Developer Documentation

このドキュメントは、開発者が Inception 環境をゼロからセットアップし、Makefile と Docker Compose でビルド・起動・管理し、データ永続化の仕組みを説明できるようにするためのメモです。レビュー中のカンペとしても使えるように、確認コマンドと口頭説明ポイントを入れています。

## 1. 前提条件

実行環境:

- 42 の評価要件に沿って VM 内で実行する
- Docker Engine が使えること
- Docker Compose v2 が使えること
- `make`, `curl`, `openssl` が使えること
- `/home/tvaroux/data/` 配下に bind mount 用ディレクトリを作れること

確認:

```sh
docker --version
docker compose version
make --version
```

作業ディレクトリ:

```sh
cd /home/tvaroux/Desktop/inception/tom_inception_0622
```

主要構成:

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

## 2. ゼロからのセットアップ

### 2-1. ホスト側データディレクトリ

Compose の volume は Docker 管理領域だけではなく、ホスト上の以下の実ディレクトリへ bind mount します。

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

意味:

- `/home/tvaroux/data/mariadb` は MariaDB の DB 実体を保存します。
- `/home/tvaroux/data/wordpress` は WordPress の PHP ファイル、アップロード、設定ファイルなどを保存します。
- コンテナを消しても、このディレクトリが残っていればデータは残ります。

### 2-2. `.env`

`srcs/.env` に機密ではない設定を書きます。

例:

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

注意:

- `WP_ADMIN_USER` は `admin` や `administrator` など、課題で禁止されやすい名前にしません。
- この実装の WordPress entrypoint は編集者ユーザーとして `WP_USER` と `WP_USER_EMAIL` を読みます。
- パスワードは `.env` に置きません。

### 2-3. Secrets

`secrets/` 配下に password 用ファイルを作ります。

```sh
mkdir -p secrets
printf 'db_password_here\n' > secrets/db_password.txt
printf 'db_root_password_here\n' > secrets/db_root_password.txt
printf 'wp_admin_password_here\n' > secrets/wp_admin_password.txt
printf 'wp_editor_password_here\n' > secrets/wp_editor_password.txt
```

Compose 定義:

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

コンテナ内の見え方:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_editor_password
```

レビューでの説明:

- `.env` は設定、secrets はパスワードです。
- secrets はプロセス環境変数ではなくファイルとしてマウントされます。
- Git にパスワードを入れないために使っています。

## 3. ビルドと起動

Makefile は内部で以下を使います。

```make
DC = docker compose -f ./srcs/docker-compose.yml
```

起動:

```sh
make up
```

実行内容:

```sh
docker compose -f ./srcs/docker-compose.yml up --detach --build
```

ビルドのみ:

```sh
make build
```

ビルド済みイメージで起動:

```sh
make up-no-build
```

停止:

```sh
make down
```

コンテナと Docker volume を削除:

```sh
make down-v
```

再起動:

```sh
make re
```

Compose 設定検証:

```sh
docker compose -f srcs/docker-compose.yml config
```

## 4. Docker Compose の構成

サービス:

| サービス | image | build context | container_name | restart |
|---|---|---|---|---|
| `mariadb` | `mariadb:banana` | `./requirements/mariadb` | `mariadb` | `always` |
| `wordpress` | `wordpress:peach` | `./requirements/wordpress` | `wordpress` | `always` |
| `nginx` | `nginx:apple` | `./requirements/nginx` | `nginx` | `always` |

ネットワーク:

```yaml
networks:
  network_cake:
    driver: bridge
```

口頭説明:

- `network_cake` は専用の bridge network です。
- コンテナ同士はサービス名で名前解決できます。
- NGINX は `wordpress:9000` に FastCGI で渡します。
- WordPress は `mariadb:3306` に SQL 接続します。
- `network: host` や `links` は使っていません。

公開ポート:

```yaml
nginx:
  ports:
    - "443:443"
```

口頭説明:

- ホストから見える入口は HTTPS の `443` のみです。
- MariaDB と WordPress は外部公開しません。

## 5. 各コンテナの実装ポイント

### 5-1. MariaDB

Dockerfile:

- ベースは `alpine:3.23`
- `mariadb` と `mariadb-client` をインストール
- `/var/lib/mysql` をデータディレクトリとして使う
- `conf/zzz-mariadb.cnf` をコピー
- `tools/entrypoint.sh` を PID 1 として実行

設定:

```ini
bind-address = 0.0.0.0
port = 3306
skip-networking = 0
```

entrypoint の流れ:

1. `/var/lib/mysql/mysql` が無ければ初回初期化と判断する。
2. `mariadb-install-db` でシステム DB を作る。
3. `mariadbd --user=mysql --skip-networking &` で一時起動する。
4. `mariadb-admin ping` で起動待ちする。
5. `/run/secrets/db_password` を読んで WordPress 用 DB とユーザーを作る。
6. 一時サーバーを `mariadb-admin shutdown` で止める。
7. 最後に `exec mariadbd --user=mysql` で本番起動する。

初期化 SQL の意味:

```sql
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY '...';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
FLUSH PRIVILEGES;
```

説明ポイント:

- 初回だけ初期化するので、既存データを再起動で壊しません。
- `wpuser@'%'` は他コンテナから TCP 接続するためのユーザーです。
- 本番プロセスは `exec` で PID 1 になり、コンテナの signal を受け取れます。

### 5-2. WordPress

Dockerfile:

- ベースは `alpine:3.23`
- `php83`, `php83-fpm`, `php83-mysqli` などをインストール
- `wp-cli.phar` を `/usr/local/bin/wp` に配置
- PHP-FPM 設定 `www.conf` をコピー
- `tools/entrypoint.sh` を起動する

PHP-FPM:

```ini
listen = 9000
```

entrypoint の流れ:

1. `/run/secrets/db_password` を読む。
2. `mariadb-admin ping --host=mariadb --port=3306` で DB 起動を待つ。
3. `/var/www/html/wp-settings.php` が無ければ `wp core download` する。
4. `wp-config.php` が無ければ DB 接続情報を使って作成する。
5. `wp core is-installed` が false なら WordPress を初期インストールする。
6. 管理者 `WP_ADMIN_USER` と編集者 `WP_USER` を作る。
7. `exec php-fpm83 -F` で PHP-FPM をフォアグラウンド起動する。

説明ポイント:

- WordPress コンテナには NGINX を入れていません。
- Web サーバーと PHP 実行環境を分離しています。
- `wp-cli` は WordPress の初期化とユーザー作成に使います。
- `php-fpm83 -F` はデーモン化せず、コンテナのメインプロセスとして動かすためです。

### 5-3. NGINX

Dockerfile:

- ベースは `alpine:3.23`
- `nginx` と `openssl` をインストール
- 自己署名証明書を `/etc/nginx/ssl/` に作る
- `conf/zzz-nginx.conf` を `/etc/nginx/nginx.conf` にコピー
- `nginx -g "daemon off;"` でフォアグラウンド起動する

設定:

```nginx
listen 443 ssl;
server_name tvaroux.42.fr;
ssl_protocols TLSv1.2 TLSv1.3;
root /var/www/html;

location ~ \.php$ {
    fastcgi_pass wordpress:9000;
}
```

説明ポイント:

- TLS 終端は NGINX が担当します。
- `ssl_protocols TLSv1.2 TLSv1.3;` により TLS 1.2 以上を使います。
- PHP は NGINX 自身では処理せず、`wordpress:9000` の PHP-FPM に渡します。
- `daemon off;` により NGINX を PID 1 のメインプロセスとして動かします。

## 6. コンテナ、イメージ、ボリュームの管理コマンド

状態確認:

```sh
docker compose -f srcs/docker-compose.yml ps
docker ps
```

ログ:

```sh
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

イメージ:

```sh
docker images | grep -E 'mariadb|wordpress|nginx'
```

ネットワーク:

```sh
docker network ls | grep network_cake
docker network inspect srcs_network_cake
```

ボリューム:

```sh
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
```

コンテナ内に入る:

```sh
docker exec --interactive --tty mariadb sh
docker exec --interactive --tty wordpress sh
docker exec --interactive --tty nginx sh
```

Makefile の inspect:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

## 7. データ保存場所と永続化

Compose の volume:

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

保存場所:

| データ | コンテナ内 | ホスト側 |
|---|---|---|
| MariaDB DB files | `/var/lib/mysql` | `/home/tvaroux/data/mariadb` |
| WordPress files | `/var/www/html` | `/home/tvaroux/data/wordpress` |

永続化の説明:

- Docker volume 名は Compose プロジェクト名が付いて `srcs_mariadb_data` のようになります。
- 実体は Docker の管理ディレクトリではなく `/home/tvaroux/data/...` に bind mount されています。
- コンテナを削除しても、ホスト側ディレクトリが残っていれば DB と WordPress ファイルは残ります。
- 完全に初期化したい場合は `make down-v` に加えて `/home/tvaroux/data/mariadb` と `/home/tvaroux/data/wordpress` の中身を削除します。

永続化デモ:

```sh
# 1. WordPress 管理画面で投稿やコメントを追加
# 2. コンテナを停止
make down

# 3. 再起動
make up-no-build

# 4. ブラウザまたは SQL で追加内容が残っていることを確認
```

SQL 確認:

```sh
docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SELECT ID, post_title, post_status, post_type FROM wp_posts WHERE post_type = '\''post'\'';"'
```

## 8. レビュー用チェックコマンド

禁止事項チェック:

```sh
grep -rnE 'network:\s*host|links:|--link' srcs Makefile || echo "OK: no forbidden network setting"
grep -rnE 'tail -f|sleep infinity|/dev/null|/dev/random|& *bash|& *sh' srcs/requirements/*/Dockerfile srcs/requirements/*/tools || echo "OK: no fake daemon keepalive"
grep -n '^FROM' srcs/requirements/*/Dockerfile
```

Compose 起動確認:

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

Volume:

```sh
docker volume inspect srcs_mariadb_data --format '{{ .Options.device }}'
docker volume inspect srcs_wordpress_data --format '{{ .Options.device }}'
```

## 9. とらぶるとか

### `secrets` が見つからない

症状:

```text
cat: can't open '/run/secrets/db_password': No such file or directory
```

原因:

- secret ファイルが無い
- ファイル名が Compose の指定と違う
- Compose 経由ではなく `docker run` 単体で起動し、secret mount をしていない

対処:

```sh
ls -l secrets/
docker compose -f srcs/docker-compose.yml config
```

### WordPress が DB に接続できない

確認:

```sh
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

説明:

- WordPress は `mariadb:3306` に接続します。
- `localhost` ではありません。コンテナ内部の `localhost` は WordPress コンテナ自身です。
- MariaDB ユーザーは `'wpuser'@'%'` として作成され、他コンテナからの TCP 接続を許可します。

### `wpuser@localhost` で拒否される

例:

```text
ERROR 1045 (28000): Access denied for user 'wpuser'@'localhost'
```

説明:

- `wpuser` は `wpuser@'%'` として作られています。
- コンテナ内で `localhost` 接続すると UNIX socket や `localhost` 扱いになり、意図と違うユーザー判定になることがあります。
- WordPress からは `mariadb` ホスト名で TCP 接続するため問題ありません。

## 10. 口頭説明の短いまとめ

このプロジェクトは、NGINX、WordPress/PHP-FPM、MariaDB を 1 サービス 1 コンテナで分離し、Docker Compose でネットワーク、secrets、volumes をまとめて管理する構成です。外部公開は NGINX の HTTPS `443` のみで、WordPress は PHP-FPM として `9000`、MariaDB は内部ネットワークで `3306` を使います。データは `/home/tvaroux/data/mariadb` と `/home/tvaroux/data/wordpress` に bind mount されるため、コンテナを作り直しても永続化されます。パスワードは Git に入れず、Docker secrets として `/run/secrets/` から読みます。
