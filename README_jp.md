*このプロジェクトは、42カリキュラムの一環として tvaroux によって作成されました。*

# Inception

## 概要

Inception は、42 のシステム管理系プロジェクトです。目的は、Docker、Docker Compose、カスタムサービスイメージを使って、小さく再現可能な Web インフラを構築することです。

このプロジェクトでは、3 つの独立したコンテナで WordPress サイトを動かします。

- `nginx`: HTTPS の入口。ホストに公開される唯一のサービスで、`443` 番ポートを使います
- `wordpress`: PHP-FPM で動く WordPress。内部ポート `9000` で NGINX から接続されます
- `mariadb`: WordPress が使うデータベースサーバー。内部ポート `3306` で WordPress から接続されます

スタック全体は `srcs/docker-compose.yml` で管理します。各サービスは `srcs/requirements/<service>/` 配下の専用 Dockerfile からビルドされ、それぞれ専用の設定ファイルと起動スクリプトを持っています。

リクエストの流れ:

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
│  │                 tvaroux_network (bridge)              │  │
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
|-- secrets/
|   |-- db_password.txt
|   |-- db_root_password.txt
|   |-- wp_admin_password.txt
|   `-- wp_editor_password.txt
`-- srcs/
    |-- .env
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

Docker を使うことで、サービスごとに実行環境を分離し、スタック全体を再現しやすくしています。Docker Compose は、専用ブリッジネットワーク、永続データ用ボリューム、`.env` による非機密設定、Docker secrets によるパスワード注入をまとめて管理します。

## 手順

### 前提条件

コマンドはプロジェクトルートから実行します。

```sh
cd tom_inception_0622
```

Docker Engine と Docker Compose がインストールされている必要があります。また、スタック起動前にホスト側のデータディレクトリを作成しておきます。

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

非機密の設定値は `srcs/.env` に作成します。

```env
DOMAIN_NAME=tvaroux.42.fr
MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser
MARIADB_PORT=3306
WP_ADMIN_USER=boss42
WP_ADMIN_EMAIL=admin@example.com
WP_USER=wpeditor
WP_USER_EMAIL=editor@example.com
```

Docker secret 用のファイルを `secrets/` 配下に作成します。

```sh
mkdir -p secrets
printf 'database_user_password\n' > secrets/db_password.txt
printf 'database_root_password\n' > secrets/db_root_password.txt
printf 'wordpress_admin_password\n' > secrets/wp_admin_password.txt
printf 'wordpress_editor_password\n' > secrets/wp_editor_password.txt
```

これらのファイルには認証情報が含まれるため、Git にコミットしてはいけません。

必要に応じて、評価に使う VM またはホストの `/etc/hosts` にドメインを追加します。

```text
127.0.0.1 tvaroux.42.fr
```

### ビルドと起動

イメージをビルドし、コンテナを起動します。

```sh
make up
```

このターゲットは内部で次を実行します。

```sh
docker compose -f ./srcs/docker-compose.yml up --detach --build
```

起動後、サイトには以下からアクセスできます。

```text
https://tvaroux.42.fr
https://127.0.0.1
```

証明書は自己署名証明書なので、ブラウザの警告は想定どおりです。

### 便利なコマンド

```sh
make build
```

コンテナは起動せず、イメージだけをビルドします。

```sh
make up-no-build
```

既存イメージを再ビルドせずに起動します。

```sh
make down
```

コンテナを停止して削除します。

```sh
make down-v
```

コンテナを停止し、Compose ボリュームも削除します。

```sh
make re
```

`make down` のあとに `make up` を実行します。

```sh
make curl-https
```

`curl --insecure --verbose` で HTTPS エンドポイントを確認します。

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

各コンテナの状態、PID、ステータス、再起動回数を確認します。

## サービス

### NGINX

NGINX イメージは `srcs/requirements/nginx/Dockerfile` からビルドされます。

重要ポイント:

- ベースイメージ: `alpine:3.23`
- 実行時パッケージ: `nginx`, `openssl`
- 自己署名 TLS 証明書と秘密鍵はイメージビルド時に生成されます
- 設定ファイル: `srcs/requirements/nginx/conf/zzz-nginx.conf`
- HTTPS サーバーは `443 ssl` で待ち受けます
- TLS プロトコルは `TLSv1.2 TLSv1.3` に制限しています
- PHP ファイルは FastCGI で `wordpress:9000` に転送されます
- NGINX は `nginx -g 'daemon off;'` によってフォアグラウンドで動き続けます

ホストにポートを公開するのは NGINX だけです。

```yaml
ports:
  - "443:443"
```

WordPress と MariaDB はホストへ直接公開されません。

### WordPress / PHP-FPM

WordPress イメージは `srcs/requirements/wordpress/Dockerfile` からビルドされます。

重要ポイント:

- ベースイメージ: `alpine:3.23`
- 実行時パッケージには `php83`, `php83-fpm`, `php83-mysqli`, `php83-curl`, XML 系モジュール、mbstring が含まれます
- WP-CLI は `/usr/local/bin/wp` としてインストールされます
- PHP-FPM は `9000` 番ポートで待ち受けます
- WordPress ファイルは `/var/www/html` に保存されます
- コンテナは MariaDB の起動を待ってから WordPress をインストールします
- パスワードは `/run/secrets/` から読みます
- PHP-FPM は `exec php-fpm83 -F` によってフォアグラウンドで動き続けます

初回起動時、`tools/entrypoint.sh` は以下を行います。

1. `/run/secrets/db_password` から DB パスワードを読みます。
2. `mariadb` が `${MARIADB_PORT:-3306}` で応答するまで待ちます。
3. `/var/www/html/wp-settings.php` がなければ WordPress core をダウンロードします。
4. `wp-config.php` がなければ作成します。
5. WordPress が未インストールなら `wp core install` を実行します。
6. 管理者ユーザーと編集者ユーザーを 1 人ずつ作成します。
7. PHP-FPM を PID 1 として起動します。

管理者ユーザー名には `admin` または `Admin` を含めてはいけません。このプロジェクトでは `boss42` のような値を使います。

### MariaDB

MariaDB イメージは `srcs/requirements/mariadb/Dockerfile` からビルドされます。

重要ポイント:

- ベースイメージ: `alpine:3.23`
- 実行時パッケージ: `mariadb`, `mariadb-client`
- 設定ファイル: `srcs/requirements/mariadb/conf/zzz-mariadb.cnf`
- MariaDB は Docker ネットワーク内で `0.0.0.0` に bind します
- MariaDB は `3306` 番ポートで待ち受けます
- データベースファイルは `/var/lib/mysql` に保存されます
- サービスは `exec mariadbd --user=mysql` で起動されます

初回起動時、`tools/entrypoint.sh` は以下を行います。

1. `/var/lib/mysql/mysql` が存在するか確認します。
2. 存在しない場合、`mariadb-install-db` でデータディレクトリを初期化します。
3. `--skip-networking` 付きで一時 MariaDB サーバーを起動します。
4. `mariadb-admin ping` で起動を待ちます。
5. `/run/secrets/db_password` からアプリケーション用 DB パスワードを読みます。
6. 匿名ユーザーとデフォルトの `test` データベースを削除します。
7. WordPress 用データベースを作成します。
8. host `%` の `${MARIADB_USER}` を作成します。
9. `${MARIADB_DATABASE}.*` への権限を付与します。
10. 一時サーバーを停止します。
11. 本番 MariaDB サーバーを PID 1 として起動します。

初期化ガードにより、コンテナを再起動しても既存データは上書きされません。

## 主な設計選択

### 仮想マシン vs Docker

| 観点 | 仮想マシン | Docker コンテナ |
| --- | --- | --- |
| 仮想化レベル | ハードウェアレベルの仮想化 | OS レベルのプロセス分離 |
| カーネル | 完全なゲスト OS とカーネルを実行する | ホストのカーネルを共有する |
| 起動速度 | 通常は遅め | 通常は速い |
| リソース使用量 | 重い | 軽い |
| 向いている用途 | OS 全体の分離 | 1 サービスと依存関係のパッケージ化 |

subject では仮想化環境でプロジェクトを実行することが求められるため、評価時には VM の中で Docker を動かすことがあります。その VM 内では、NGINX、PHP-FPM、MariaDB を直接インストールするより、Docker コンテナに分ける方が、各サービスを独立してビルド・起動・停止・検査・再ビルドしやすくなります。

### Secrets vs 環境変数

| 観点 | Docker secrets | 環境変数 |
| --- | --- | --- |
| 向いている用途 | パスワードや認証情報 | 機密ではない設定 |
| 露出方法 | `/run/secrets/` にファイルとしてマウントされる | プロセス環境として見える |
| このプロジェクトでの用途 | DB と WordPress のパスワード | ドメイン、DB 名、ユーザー名 |

Compose ファイルでは以下の Docker secrets を宣言しています。

- `db_password`
- `db_root_password`
- `wp_admin_password`
- `wp_editor_password`

実行時スクリプトは必要な secret をファイルとして読みます。例:

```sh
cat /run/secrets/db_password
```

MariaDB の初回初期化では、一時サーバーに対してローカル root 接続でセットアップを行います。WordPress から使う DB ユーザーは `db_password` を使って作成されます。

環境変数は、`DOMAIN_NAME`、`MARIADB_DATABASE`、`MARIADB_USER`、`WP_ADMIN_USER`、`WP_USER` など、設定として必要だが認証情報ではない値に使います。

### Docker Network vs Host Network

| 観点 | Docker ブリッジネットワーク | ホストネットワーク |
| --- | --- | --- |
| 分離 | サービスはプライベートな Docker ネットワーク内に残る | コンテナがホストの network namespace を共有する |
| サービス発見 | Docker DNS によりサービス名で解決できる | Compose のサービス名による分離がない |
| ポート公開 | 選んだポートだけを公開する | サービスがホストポートに直接 bind できる |
| このプロジェクト | `network_cake` | 使用しない |

このスタックでは `network_cake` という専用ブリッジネットワークを使います。これにより、以下の通信ができます。

- NGINX は `wordpress:9000` として WordPress に接続する
- WordPress は `mariadb:3306` として MariaDB に接続する
- MariaDB はホストに直接公開されず、内部ネットワークに閉じる

公開されるのは `443` だけなので、host network よりも制御しやすく安全です。

### Docker Volumes vs Bind Mounts

| 観点 | Docker volume | Bind mount |
| --- | --- | --- |
| 管理元 | Docker | ホストファイルシステムのパス |
| 移植性 | 固定ホストパスへの依存が少ない | ホストパスに直接依存する |
| 可視性 | Docker コマンドで管理する | ホスト上で直接見える |
| このプロジェクト | local driver の Compose volumes | `driver_opts` で `/home/tvaroux/data/...` に bind |

このプロジェクトでは Docker volumes を定義しつつ、local driver の bind オプションを使っています。

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

結果として、以下のようになります。

- MariaDB のデータは `/home/tvaroux/data/mariadb` に永続化されます
- WordPress のファイルは `/home/tvaroux/data/wordpress` に永続化されます
- コンテナを再ビルドまたは再作成しても、サイトのデータは消えません

## レビュー用メモ

### クイックヘルスチェック

```sh
docker compose -f srcs/docker-compose.yml ps
docker network ls
docker volume ls
docker images | grep -E 'mariadb|wordpress|nginx'
```

期待されるサービスイメージタグ:

```text
mariadb:banana
wordpress:peach
nginx:apple
```

期待されるコンテナ:

```text
mariadb
wordpress
nginx
```

期待されるネットワーク:

```text
srcs_network_cake
```

Compose は宣言されたネットワーク名 `network_cake` にプロジェクト名を prefix として付けるため、Docker 上では通常 `srcs_network_cake` と表示されます。

### TLS 確認

```sh
curl -vk https://127.0.0.1/
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```

説明ポイント:

- HTTPS の終端は NGINX が担当します。
- 証明書は自己署名証明書です。
- NGINX 設定では TLS 1.2 と TLS 1.3 を許可しています。
- Compose では `80` 番ポートを公開しておらず、公開されるのは `443` だけです。

### SQL 確認

MariaDB コンテナに入ります。

```sh
docker exec -it mariadb sh
```

WordPress データベースに接続します。

```sh
mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE"
```

便利な SQL:

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

ホストから 1 行でテーブル確認する場合:

```sh
docker exec -it mariadb sh -c 'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

これにより、WordPress が DB を初期化済みであること、そして実際のサイトデータが MariaDB に保存されていることを示せます。

### 永続化確認

1. WordPress で投稿、コメント、ページなどを追加または編集します。
2. `make down` を実行します。
3. `make up-no-build` を実行します。
4. サイトを開き、内容が残っていることを確認します。
5. 同じ内容を SQL でも確認します。

永続化が効く理由は、DB と WordPress ファイルが使い捨てコンテナの内部だけでなく、ホスト backed volume に保存されているためです。

### 設定変更の例

公開 HTTPS ポートの変更を求められた場合、ホスト側のマッピングだけを変えます。

```yaml
ports:
  - "8443:443"
```

その後、コンテナを再作成します。

```sh
make down
make up-no-build
curl -vk https://127.0.0.1:8443/
```

NGINX 設定ファイルや Dockerfile のように、イメージへコピーされるファイルを変更した場合は、起動前に該当イメージを再ビルドします。

```sh
make down
make build
make up-no-build
```

### 禁止パターンの説明

コンテナは、`tail -f`、`sleep infinity`、無限ループなどのダミーコマンドで生かすべきではありません。本物のサービスプロセスをフォアグラウンドで動かすことでコンテナを生存させます。

このプロジェクトでは以下のようになっています。

- NGINX は `nginx -g 'daemon off;'`
- WordPress は `exec php-fpm83 -F`
- MariaDB は `exec mariadbd --user=mysql`

これにより、サービスプロセスが PID 1 になり、コンテナのライフサイクルシグナルを適切に受け取れます。

## 参考資料

### 公式ドキュメント

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

### AI の使用について

このプロジェクトでは、学習およびドキュメント作成の補助として AI を使用しました。

AI は以下を補助しました。

- image、container、volume、network、secret など Docker の概念整理
- 仮想マシンと Docker コンテナの比較
- Docker Compose の設計方針のレビュー
- NGINX、FastCGI、PHP-FPM、MariaDB 初期化、WP-CLI の流れの理解
- 起動スクリプトのロジック整理
- レビュー用の検証コマンド準備
- この README と関連学習メモの構成整理

AI はプロジェクト理解の代替として使ったものではありません。最終的な設計判断、実装、デバッグ、テスト、レビューでの説明は学生本人が確認し、責任を持っています。
