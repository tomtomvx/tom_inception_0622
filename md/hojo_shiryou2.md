## USER補助資料

## WordPress data の確認

database が初期化済みで空ではないことを確認します。

```sh
docker exec -it mariadb sh
mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE"
```

よく使う SQL:

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

MariaDB client を抜けます。

```sql
exit;
```

container shell を抜けます。

```sh
exit
```

host から 1 行で確認する場合:

```sh
docker exec -it mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

## 永続化確認

data は host directory に bind された Docker volume に保存されます。

| Data | Host path | Container path |
| --- | --- | --- |
| MariaDB database files | `/home/tvaroux/data/mariadb` | `/var/lib/mysql` |
| WordPress files | `/home/tvaroux/data/wordpress` | `/var/www/html` |

レビューでの実演:

1. WordPress で post、page、comment などを追加します。
2. `make down` を実行します。
3. `make up-no-build` を実行します。
4. site を開き直します。
5. 変更した内容が残っていることを確認します。
6. 必要なら SQL でも同じ data を確認します。

完全に clean install する場合:

```sh
make down-v
sudo rm -rf /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
make up
```

## Troubleshooting

`502 Bad Gateway` が出る場合は、WordPress または PHP-FPM がまだ起動中の可能性があります。
少し待ってから log を確認します。

```sh
docker compose -f srcs/docker-compose.yml logs wordpress
```

WordPress が database に接続できない場合:

```sh
docker compose -f srcs/docker-compose.yml ps mariadb
docker compose -f srcs/docker-compose.yml logs mariadb
ls -l secrets/
cat srcs/.env
```

`https://tvaroux.42.fr` が browser で開けない場合は、`https://127.0.0.1` を使うか、
`/etc/hosts` を確認します。

# hojo

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





## DEV 補助資料


## Docker Compose 設計

services:

| Service | Container | Image tag | Build context |
| --- | --- | --- | --- |
| `mariadb` | `mariadb` | `mariadb:banana` | `srcs/requirements/mariadb` |
| `wordpress` | `wordpress` | `wordpress:peach` | `srcs/requirements/wordpress` |
| `nginx` | `nginx` | `nginx:apple` | `srcs/requirements/nginx` |

network:

```yaml
networks:
  network_cake:
    driver: bridge
```

Docker 上では Compose project prefix が付き、`srcs_network_cake` のように表示される場合があります。

host に port publish するのは NGINX だけです。

```yaml
ports:
  - "443:443"
```

container 間の通信:

- NGINX -> `wordpress:9000`
- WordPress -> `mariadb:3306`

## Service startup flow

### NGINX

Files:

- `srcs/requirements/nginx/Dockerfile`
- `srcs/requirements/nginx/conf/zzz-nginx.conf`

重要点:

- base image: `alpine:3.23`
- runtime package: `nginx`, `openssl`
- image build 時に自己署名証明書を生成
- certificate path: `/etc/nginx/ssl/tvaroux_server.crt`
- key path: `/etc/nginx/ssl/tvaroux_server.key`
- `443 ssl` で listen
- `TLSv1.2 TLSv1.3` を許可
- PHP request を `wordpress:9000` に FastCGI で転送
- `nginx -g 'daemon off;'` で foreground 実行

説明: NGINX は唯一の public entry point です。TLS を終端し、PHP request を PHP-FPM に渡します。

### WordPress / PHP-FPM

Files:

- `srcs/requirements/wordpress/Dockerfile`
- `srcs/requirements/wordpress/conf/www.conf`
- `srcs/requirements/wordpress/tools/entrypoint.sh`

重要点:

- base image: `alpine:3.23`
- runtime package: `php83`, `php83-fpm`, `php83-mysqli`, `php83-curl`,
  `php83-xml`, `php83-dom`, `php83-mbstring`
- WP-CLI は `/usr/local/bin/wp`
- working directory: `/var/www/html`
- PHP-FPM は `9000` で listen
- `exec php-fpm83 -F` で foreground 実行

startup flow:

1. `/run/secrets/db_password` から DB password を読む。
2. MariaDB が `mariadb:${MARIADB_PORT:-3306}` で認証付き ping に応答するまで待つ。
3. `/var/www/html/wp-settings.php` がなければ WordPress core を download。
4. `wp-config.php` がなければ作成。
5. WordPress が未 install なら `wp core install`。
6. editor user を作成。
7. PHP-FPM を PID 1 として起動。

注意: secret を後から変えても、既存の `wp-config.php` や WordPress user password は自動更新されません。
clean reset する場合は persistent data を消して起動し直します。

### MariaDB

Files:

- `srcs/requirements/mariadb/Dockerfile`
- `srcs/requirements/mariadb/conf/zzz-mariadb.cnf`
- `srcs/requirements/mariadb/tools/entrypoint.sh`

重要点:

- base image: `alpine:3.23`
- runtime package: `mariadb`, `mariadb-client`
- data directory: `/var/lib/mysql`
- `0.0.0.0` に bind
- `3306` で listen
- `exec mariadbd --user=mysql` で foreground 実行

初回起動 flow:

1. `/var/lib/mysql/mysql` があるか確認。
2. なければ `mariadb-install-db` を実行。
3. temporary MariaDB を `--skip-networking` で起動。
4. `mariadb-admin ping` を待つ。
5. `/run/secrets/db_password` から application DB password を読む。
6. anonymous user を削除。
7. default の `test` database を削除。
8. `${MARIADB_DATABASE}` を作成。
9. host `%` の `${MARIADB_USER}` を作成。
10. `${MARIADB_DATABASE}.*` への権限を付与。
11. temporary server を停止。
12. real MariaDB server を PID 1 として起動。

`/var/lib/mysql/mysql` が初期化 guard なので、restart 時に既存 DB を上書きしません。


## 検証と command

### General checks

```sh
docker compose -f srcs/docker-compose.yml ps
docker images | grep -E 'mariadb|wordpress|nginx'
docker network ls | grep network_cake
docker volume ls
```

### TLS checks

```sh
curl -vk https://127.0.0.1/
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```

説明:

- HTTPS は NGINX が担当。
- `ssl_protocols TLSv1.2 TLSv1.3;` を設定。
- 証明書は local project 用の自己署名証明書。
- publish している port は `443:443` のみ。

### SQL checks

MariaDB に入る:

```sh
docker exec -it mariadb sh
```

WordPress database に接続:

```sh
mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE"
```

よく使う SQL:

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

host から 1 行で確認:

```sh
docker exec -it mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

これにより、WordPress が DB を初期化済みで、実 site data が MariaDB に保存されていることを示せます。

### Backup と restore

backup:

```sh
docker compose -f srcs/docker-compose.yml exec mariadb sh -c 'mariadb-dump -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE"' > backup.sql
```

restore:

```sh
docker compose -f srcs/docker-compose.yml exec -T mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE"' < backup.sql
```

## 設定変更例

評価者に public HTTPS port の変更を求められた場合、host 側 mapping だけを変えます。

```yaml
ports:
  - "8443:443"
```

container を作り直します。

```sh
make down
make up-no-build
curl -vk https://127.0.0.1:8443/
```

NGINX container 内の listen port 自体を変える場合は、`zzz-nginx.conf` と Compose mapping の両方を変更します。
設定 file は image に copy されるため、rebuild が必要です。

```sh
make down
make build
make up-no-build
```

## Clean evaluation start

評価者が clean Docker state を求めた場合、通常は Makefile ではなく手で実行します。

```sh
docker stop $(docker ps -qa)
docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
sudo rm -rf /home/tvaroux/data/*
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
```

その後、設定を作り直して起動します。

```sh
cp srcs/.env_sample srcs/.env
mkdir -p secrets
echo -n pw > secrets/db_password.txt
echo -n pw > secrets/wp_admin_password.txt
echo -n pw > secrets/wp_editor_password.txt
make up
```

## 口頭 メモ

- Docker は service と依存関係を image にまとめ、再現可能な runtime を作る。
- Compose は service、secret、volume、network を 1 file で管理する。
- VM は OS 丸ごとを仮想化し、Docker は host kernel を共有して process を隔離する。
- password は `/run/secrets/` に file mount し、`.env` は非 secret 設定に使う。
- `network_cake` は bridge network。host network は使わない。
- service name により `wordpress` と `mariadb` が DNS 解決される。
- host port を expose するのは NGINX だけ。
- data は `/home/tvaroux/data/...` に永続化される。
- PID 1 は実 service process なので、container stop signal を正しく受け取れる。
- MariaDB は `/var/lib/mysql/mysql` を guard にし、restart で DB を上書きしない。
- WordPress も core/config/install 状態を見て、初回だけ初期化する。





## hojo

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
