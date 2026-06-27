*This project has been created as part of the 42 curriculum by tvaroux.*

# Inception 日本語版

このファイルは `README.md` の日本語版です。subject 上の提出用 README は英語である必要があるため、正式な提出説明は `README.md` を参照してください。この日本語版は、レビュー前の確認と口頭説明用の補助ドキュメントです。

## Description

Docker を使って、 Web インフラを自分で構築する課題です。

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
│  │  │         │    │  php-fpm    │    │             │    │  │
│  │  │         │    │  wp-cli     │    │             │    │  │
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

プロジェクトルートに移動してください。

```sh
cd <your_repozitory>
```

### ホスト側データディレクトリを作成する

Compose の volume はホスト側ディレクトリへ bind するため、起動前に作成します。

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

### `.env` を作成する

`srcs/.env_sample`から `srcs/.env` を作成します。

```sh
cp srcs/.env_sample srcs/.env
```

例:

```env
DOMAIN_NAME=tvaroux.42.fr
MARIADB_PORT=3306

WP_ADMIN_USER=ado
WP_ADMIN_EMAIL=ado@example.com
WP_USER=wpeditor
WP_USER_EMAIL=editor@example.com
```

WordPress の管理者ユーザー名には `admin` や `Admin` を含めてはいけません。

```sh
grep -i admin srcs/.env
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

### おすすめ Make ターゲット

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
- VirtualBox manual: https://www.virtualbox.org/manual/UserManual.html
- RFC 8446, TLS 1.3: https://datatracker.ietf.org/doc/html/rfc8446

- [Docker（日本語版）](https://www.oreilly.com/library/view/docker/9784873117768/) — O'Reilly Japan, 2016年8月, 384ページ（紙の本で参照）

### AI usage

この project では、AI を学習とドキュメント整理の補助として使いました。

AI が助けた内容:

- image、container、volume、network、secret など Docker concept の整理
- Virtual Machine と Docker container の比較
- Docker Compose の設計選択の確認
- NGINX、FastCGI、PHP-FPM、MariaDB initialization、WP-CLI workflow の理解
- defense 用の確認 command と SQL check の整理
- README と学習メモの構成整理

AI は理解の代替ではなく、説明や整理の補助として使いました。最終的な設計判断、実装、debug、test、defense explanation は提出者が確認し、自分の責任で説明できる状態にしています。
