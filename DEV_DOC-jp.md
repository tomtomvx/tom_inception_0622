# DEV_DOC_jp - 開発者向け技術ドキュメント

このドキュメントは、開発者が Inception project をゼロから setup し、build、起動、
確認、レビュー説明を行うための技術メモです。

## Project 構成

```text
.
|-- Makefile
|-- README.md
|-- README-jp.md
|-- USER_DOC.md
|-- USER_DOC_jp.md
|-- DEV_DOC.md
|-- DEV_DOC_jp.md
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

service ごとに Dockerfile、設定ファイル、起動 script を分けています。全体構成は
`srcs/docker-compose.yml` にあります。

## ゼロからの環境 setup

project command は repository root で実行します。

```sh
cd <your_repozitory>
```

必要なもの:

- Docker Engine
- Docker Compose plugin
- GNU Make
- smoke test 用の `curl` と `openssl`

version 確認:

```sh
docker --version
docker compose version
make --version
```

### 1. 永続化用 host directory を作る

Compose volume は local driver の bind option を使います。起動前に host directory が必要です。

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

MariaDB files は `/home/tvaroux/data/mariadb` に残ります。
WordPress files は `/home/tvaroux/data/wordpress` に残ります。

### 2. `srcs/.env` を作る

```sh
cp srcs/.env_sample srcs/.env
```

sample:

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

`.env` には secret ではない設定だけを書きます。password は `.env` に置きません。

レビューでの重要点: WordPress administrator username には `admin` や `Admin` を含めません。

### 3. Docker secrets を作る

Compose は 3 つの secret file を期待します。

```sh
mkdir -p secrets
echo -n pw > secrets/db_password.txt
echo -n pw > secrets/wp_admin_password.txt
echo -n pw > secrets/wp_editor_password.txt
```

secret の対応:

| Compose secret | Host file | Runtime path |
| --- | --- | --- |
| `db_password` | `../secrets/db_password.txt` | `/run/secrets/db_password` |
| `wp_admin_password` | `../secrets/wp_admin_password.txt` | `/run/secrets/wp_admin_password` |
| `wp_editor_password` | `../secrets/wp_editor_password.txt` | `/run/secrets/wp_editor_password` |

entrypoint script は password を file として読みます。通常の environment variable に password を置かないため、
`docker inspect` や process environment に出にくい構成です。

### 4. domain setup

domain が解決できない場合は、VM または評価 host の `/etc/hosts` に追加します。

```text
127.0.0.1 tvaroux.42.fr
```

## Build と起動

主な Makefile target:

| Target | 目的 |
| --- | --- |
| `make` / `make all` / `make up` | image を build し、container を detached 起動 |
| `make build` | image だけ build |
| `make up-no-build` | build せず、既存 image で起動 |
| `make down` | container を停止・削除 |
| `make down-v` | container と Compose volume を削除 |
| `make re` | `make down` のあと `make up` |
| `make curl-https` | `curl --insecure --verbose` で HTTPS test |
| `make inspect-nginx` | NGINX container を inspect |
| `make inspect-wordpress` | WordPress container を inspect |
| `make inspect-mariadb` | MariaDB container を inspect |

初回 build:

```sh
make up
```

同等の Compose command:

```sh
docker compose -f ./srcs/docker-compose.yml up --detach --build
```

build のみ:

```sh
make build
```

container を作り直す:

```sh
make down
make up-no-build
```

Dockerfile や image に copy される設定ファイルを変更した後:

```sh
make down
make build
make up-no-build
```

clean start:

```sh
make down-v
sudo rm -rf /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
make up
```

## Container と volume 管理 command

status:

```sh
docker compose -f srcs/docker-compose.yml ps
docker images
docker network ls
docker volume ls
```

inspect:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

shell:

```sh
docker exec --interactive --tty nginx sh
docker exec --interactive --tty wordpress sh
docker exec --interactive --tty mariadb sh
```

volume inspection:

```sh
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
```

期待する host device:

```text
/home/tvaroux/data/mariadb
/home/tvaroux/data/wordpress
```