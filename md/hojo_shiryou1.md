
## Services

### NGINX

NGINX image は `srcs/requirements/nginx/Dockerfile` からビルドされます。

重要ポイント:

- ベース image は `alpine:3.23`
- runtime package は `nginx` と `openssl`
- image tag は `nginx:apple`
- 設定ファイルは `srcs/requirements/nginx/conf/zzz-nginx.conf`
- 自己署名証明書を image build 時に生成
- HTTPS は `443 ssl` で待ち受け
- TLS は `TLSv1.2 TLSv1.3` のみに制限
- PHP request は FastCGI で `wordpress:9000` に転送
- `nginx -g 'daemon off;'` で foreground 実行

ホストに公開される port は NGINX のみです。

```yaml
ports:
  - "443:443"
```

WordPress と MariaDB はホストへ直接公開しません。

### WordPress / PHP-FPM

WordPress image は `srcs/requirements/wordpress/Dockerfile` からビルドされます。

重要ポイント:

- ベース image は `alpine:3.23`
- runtime package は `php83`, `php83-fpm`, `php83-mysqli`, `php83-curl`, XML, DOM, mbstring など
- image tag は `wordpress:peach`
- WP-CLI は `/usr/local/bin/wp` としてインストール
- PHP-FPM は `9000` 番で待ち受け
- WordPress ファイルは `/var/www/html` に保存
- MariaDB の起動を待ってから WordPress を初期化
- password は `/run/secrets/` から読む
- `exec php-fpm83 -F` で PHP-FPM を foreground 起動

初回起動時、`tools/entrypoint.sh` は次の処理をします。

1. `/run/secrets/db_password` から DB password を読む。
2. `mariadb` が `${MARIADB_PORT:-3306}` で応答するまで待つ。
3. `/var/www/html/wp-settings.php` がなければ WordPress core を download する。
4. `wp-config.php` がなければ作成する。
5. WordPress が未インストールなら `wp core install` を実行する。
6. 管理者ユーザーと editor ユーザーを 1 つずつ作成する。
7. PHP-FPM を PID 1 として起動する。

### MariaDB

MariaDB image は `srcs/requirements/mariadb/Dockerfile` からビルドされます。

重要ポイント:

- ベース image は `alpine:3.23`
- runtime package は `mariadb` と `mariadb-client`
- image tag は `mariadb:banana`
- 設定ファイルは `srcs/requirements/mariadb/conf/zzz-mariadb.cnf`
- Docker network 内で `0.0.0.0` に bind
- MariaDB は `3306` 番で待ち受け
- DB ファイルは `/var/lib/mysql` に保存
- `exec mariadbd --user=mysql` で service 起動

初回起動時、`tools/entrypoint.sh` は次の処理をします。

1. `/var/lib/mysql/mysql` が存在するか確認する。
2. なければ `mariadb-install-db` で data directory を初期化する。
3. `--skip-networking` で一時 MariaDB server を起動する。
4. `mariadb-admin ping` が成功するまで待つ。
5. `/run/secrets/db_password` から application DB password を読む。
6. anonymous user と default の `test` DB を削除する。
7. WordPress 用 database を作成する。
8. host `%` の `${MARIADB_USER}` を作成する。
9. `${MARIADB_DATABASE}.*` に権限を付与する。
10. 一時 server を shutdown する。
11. 本番用 MariaDB server を PID 1 として起動する。

初期化ガードがあるため、既存の DB データは再起動時に上書きされません。

## Defense Notes

### 評価開始時の clean start

評価者から clean Docker state を求められた場合の例です。

```sh
docker stop $(docker ps -qa)
docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
sudo rm -rf /home/tvaroux/data/*
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
```

そのあと `srcs/.env` と `secrets/*.txt` を作り直し、起動します。

```sh
make up
```

### quick health checks

```sh
docker compose -f srcs/docker-compose.yml ps
docker network ls
docker volume ls
docker images | grep -E 'mariadb|wordpress|nginx'
```

期待する container:

```text
mariadb
wordpress
nginx
```

期待する image tag:

```text
mariadb:banana
wordpress:peach
nginx:apple
```

期待する network:

```text
srcs_network_cake
```

### TLS checks

```sh
curl -vk https://127.0.0.1/
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```

説明ポイント:

- HTTPS termination は NGINX が担当する。
- 証明書は自己署名。
- NGINX config では TLS 1.2 と TLS 1.3 だけを許可。
- Compose が publish するのは `443:443` だけ。

### SQL checks

MariaDB container に入ります。

```sh
docker exec -it mariadb sh
```

WordPress database に接続します。

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

host から 1 行で確認する場合:

```sh
docker exec -it mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

`SHOW TABLES` で `wp_posts` や `wp_users` が見えれば、WordPress が DB を初期化済みで、実データが MariaDB に保存されていることを説明できます。

### Persistence checks

1. WordPress で投稿、コメント、ページ編集などを行う。
2. `make down` を実行する。
3. `make up-no-build` を実行する。
4. サイトを開き、変更した内容が残っていることを確認する。
5. SQL でも同じ内容を確認する。

データが残る理由は、MariaDB と WordPress のデータが disposable container の中だけではなく、host-backed volume に保存されているからです。

### 設定変更の例

評価中に public HTTPS port の変更を求められた場合は、host 側の mapping を変更します。

```yaml
ports:
  - "8443:443"
```

その後、container を作り直します。

```sh
make down
make up-no-build
curl -vk https://127.0.0.1:8443/
```

Dockerfile や NGINX config のように image に copy される file を変更した場合は、対象 image の rebuild が必要です。

```sh
make down
make build
make up-no-build
```

### 禁止パターンの説明

container は `tail -f`、`sleep infinity`、無限 loop のような fake command で生かしているのではありません。実際の service process を foreground で動かしています。

この project では:

- NGINX は `nginx -g 'daemon off;'`
- WordPress は `exec php-fpm83 -F`
- MariaDB は `exec mariadbd --user=mysql`

これにより、service process が PID 1 になり、container lifecycle signal を正しく受け取れます。
