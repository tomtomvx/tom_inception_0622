*This project has been created as part of the 42 curriculum by tvaroux.*

# Inception 日本語版

このファイルは `README.md` の日本語版です。subject 上の提出用 README は英語である必要があるため、正式な提出説明は `README.md` を参照してください。この日本語版は、レビュー前の確認と口頭説明用のカンペとして使うための補助ドキュメントです。

## Description

Inception は 42 のコンテナを管理するプロジェクトです。目的は、Docker と Docker Compose を使って、小さな Web インフラを自分で構築することです。サービスごとに独自の Docker image を作り、設定、起動処理、永続化、ネットワークを明確に分けています。

このプロジェクトでは、WordPress サイトを 3 つのコンテナで動かします。

- `nginx`: 外部に公開される唯一の入口。HTTPS の `443` 番ポートで待ち受けます。
- `wordpress`: WordPress を PHP-FPM で動かします。内部ポートは `9000` です。
- `mariadb`: WordPress が使うデータベースです。内部ポートは `3306` です。

全体構成は `srcs/docker-compose.yml` に書かれています。各サービスの Dockerfile、設定ファイル、起動スクリプトは `srcs/requirements/<service>/` の下に分けています。

構成図

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

リクエストの流れ:

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

主なソース構成:

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

Docker を使う理由は、サービスを分離し、同じ構成を何度でも再現しやすくするためです。Docker Compose は、3 つのサービス、専用 bridge network、永続化ボリューム、`.env`、Docker secrets をまとめて管理します。

## Instructions

### Prerequisites

- Docker Engine と Docker Compose がインストールされていること。
- VM 上での作業を想定しています。ホスト OS は Ubuntu 22.04 です。
- `srcs/.env_sample` をコピーして `srcs/.env` を作成し、必要に応じて編集してください。
- Docker secrets は `secrets/` に作成してください。Git にはコミットしないでください。
- ホストの `/etc/hosts` にドメインを追加する必要がある場合があります。
- ホストの `/home/tvaroux/data/` に、MariaDB と WordPress のデータを保存するディレクトリを新規作成してください。


### Setup

コマンドはプロジェクトルートで実行します。

```sh
cd <your_directory_name>
```

### ホスト側データディレクトリを作成する

Compose の volume はホスト側ディレクトリへ bind するため、起動前に作成します。

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

これらのパスは `srcs/docker-compose.yml` の `driver_opts.device` で使われます。

### `.env` を作成する

`srcs/.env_sample`から `srcs/.env` を作成します。

```sh
cp srcs/.env_sample srcs/.env
```

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

WordPress の管理者ユーザー名には `admin` や `Admin` を含めてはいけません。

必要なら、VM または評価環境の `/etc/hosts` にドメインを追加します。

```text
127.0.0.1 tvaroux.42.fr
```

### Docker secret ファイルを作成する

Compose が読む secret ファイルを作成します。

```sh
echo -n pw > secrets/db_password.txt
echo -n pw > secrets/wp_admin_password.txt
echo -n pw > secrets/wp_editor_password.txt
```

これらは認証情報なので Git にコミットしてはいけません。

### ビルドして起動する

image をビルドし、コンテナを起動します。

```sh
make up
```

実際には次の Compose コマンドが実行されます。

```sh
docker compose -f ./srcs/docker-compose.yml up --detach --build
```

サイトは以下で確認できます。

```text
https://tvaroux.42.fr
https://127.0.0.1
https://localhost
```

証明書は自己署名なので、ブラウザの警告は正常です。

### 便利な Make ターゲット

```sh
make up
```
コンテナをビルドして起動します。

```sh
make build
```

コンテナは起動せず、service image だけをビルドします。

```sh
make up-no-build
```

既存 image を使って、再ビルドせずに起動します。

```sh
make down
```

コンテナを停止して削除します。

```sh
make down-v
```

コンテナを停止し、Compose volume も削除します。

```sh
make re
```

`make down` のあとに `make up` を実行します。

```sh
make curl-https
```

`curl --insecure --verbose` で HTTPS endpoint を確認します。

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

コンテナの状態、PID、status、restart count を確認します。

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

## Main Design Choices

### Virtual Machines vs Docker

| Point | Virtual Machine | Docker Container |
| --- | --- | --- |
| 仮想化の単位 | hardware-level | OS-level process isolation |
| kernel | guest OS と kernel を持つ | host kernel を共有する |
| 起動速度 | 比較的遅い | 比較的速い |
| resource 使用量 | 重い | 軽い |
| 向いている用途 | OS 丸ごとの隔離 | 1 service と依存関係の package 化 |

subject では評価環境として VM を使うことがあります。その VM の中で、NGINX、PHP-FPM、MariaDB を直接インストールするのではなく Docker container に分けることで、各 service を独立して build、start、stop、inspect、rebuild できます。

### Secrets vs Environment Variables

| Point | Docker secrets | Environment variables |
| --- | --- | --- |
| 向いている用途 | password や credential | secret ではない設定値 |
| 見え方 | `/run/secrets/` に file として mount | process environment や inspect で見えやすい |
| この project | DB と WordPress の password | domain、DB 名、username |

Compose では次の Docker secrets を定義しています。

- `db_password`
- `wp_admin_password`
- `wp_editor_password`

起動スクリプトは secret を file として読みます。

```sh
cat /run/secrets/db_password
```

一方、`DOMAIN_NAME`、`MARIADB_DATABASE`、`MARIADB_USER`、`WP_ADMIN_USER`、`WP_USER` のような secret ではない設定には environment variables を使います。

### Docker Network vs Host Network

| Point | Docker bridge network | Host network |
| --- | --- | --- |
| 隔離 | private Docker network 内に service を置ける | host の network namespace を共有 |
| 名前解決 | Docker DNS で service name が解決される | Compose service name による隔離が弱い |
| port 公開 | 必要な port だけ publish | service が host port に直接 bind しやすい |
| この project | `network_cake` | 使わない |

この stack は `network_cake` という dedicated bridge network を使います。Compose の project prefix により、Docker 上では `srcs_network_cake` と表示されることがあります。

これにより、次の接続ができます。

- NGINX から WordPress へ `wordpress:9000`
- WordPress から MariaDB へ `mariadb:3306`
- MariaDB は host に公開せず private に保つ

host に publish するのは `443` だけです。

### Docker Volumes vs Bind Mounts

| Point | Docker volume | Bind mount |
| --- | --- | --- |
| 管理者 | Docker | host filesystem path |
| portability | 固定 host path への依存が少ない | host path に直接依存 |
| 見え方 | Docker command で管理 | host 上で直接見える |
| この project | local driver の Compose volume | `driver_opts` で `/home/tvaroux/data/...` に bind |

この project は Docker volume を定義しつつ、local driver の bind option を使っています。

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

結果として:

- MariaDB data は `/home/tvaroux/data/mariadb` に残る
- WordPress files は `/home/tvaroux/data/wordpress` に残る
- container を作り直しても site data は消えない

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

この project では、AI を学習とドキュメント整理の補助として使いました。

AI が助けた内容:

- image、container、volume、network、secret など Docker concept の整理
- Virtual Machine と Docker container の比較
- Docker Compose の設計選択の確認
- NGINX、FastCGI、PHP-FPM、MariaDB initialization、WP-CLI workflow の理解
- defense 用の確認 command と SQL check の整理
- README と学習メモの構成整理

AI は理解の代替ではなく、説明や整理の補助として使いました。最終的な設計判断、実装、debug、test、defense explanation は student が確認し、自分の責任で説明できる状態にしています。
