# USER_DOC-jp - ユーザー向け操作ドキュメント

このドキュメントは、Inception スタックを操作するエンドユーザーまたは管理者向けの説明です。

## サービス概要

このプロジェクトは、Docker Compose で WordPress サイトを起動します。構成は 3 つのコンテナです。

| Service | 役割 | アクセス |
| --- | --- | --- |
| `nginx` | 外部公開される HTTPS 入口。TLS 終端を担当する web サーバー | host port `443` |
| `wordpress` | PHP-FPM で動く web アプリケーション | internal port `9000` |
| `mariadb` | WordPress が使う database サーバー | internal port `3306` |

リクエストの流れ:

```text
Browser
  -> HTTPS :443
  -> NGINX
  -> FastCGI wordpress:9000
  -> WordPress / PHP-FPM
  -> SQL mariadb:3306
  -> MariaDB
```

外部に公開されるのは NGINX だけです。WordPress と MariaDB は Docker bridge network 内だけで通信します。

## 起動と停止

コマンドは repository root で実行します。

```sh
cd <your_repository>
```

初回起動前に、host 側の永続化 directory を作成します。

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

build して起動:

```sh
make up
```

`make up` は image を build し、container を background で起動します。

停止するが data は残す:

```sh
make down
```

再起動:

```sh
make re
```

既存 image を使って、build せず起動:

```sh
make up-no-build
```

container と Compose volume を削除:

```sh
make down-v
```

注意: `make down-v` は Docker volume object を削除します。ただし、この project の実データは
`/home/tvaroux/data/mariadb` と `/home/tvaroux/data/wordpress` にあります。完全に初期化したい場合だけ、
これらの host directory も削除します。

## Web サイトと管理画面へのアクセス

通常の URL:

```text
https://tvaroux.42.fr
https://127.0.0.1
https://localhost
```

`tvaroux.42.fr` が解決できない場合は、VM または評価 host の `/etc/hosts` に追加します。

```text
127.0.0.1 tvaroux.42.fr
```

証明書は自己署名なので、browser に警告が出ることがあります。これはこの project では正常です。

WordPress 管理画面:

```text
https://tvaroux.42.fr/wp-admin
https://127.0.0.1/wp-admin
```

管理者 username は `srcs/.env` にあります。

```env
WP_ADMIN_USER=ado
```

editor username も `srcs/.env` にあります。

```env
WP_USER=wpeditor
```

subject では、管理者 username に `admin` や `Admin` を含めることが禁止されます。

確認用コマンド:

```sh
grep -i admin srcs/.env
```

この project では custom username を使っています。

## 認証情報の場所と管理

secret ではない設定は `srcs/.env` に置きます。

```text
srcs/.env
```

sample から作成します。

```sh
cp srcs/.env_sample srcs/.env
```

sample の内容:

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

password は Docker secret file として `secrets/` に置きます。

```text
secrets/
```

起動前に作成します。

```sh
mkdir -p secrets
echo -n pw > secrets/db_password.txt
echo -n pw > secrets/wp_admin_password.txt
echo -n pw > secrets/wp_editor_password.txt
```

secret の対応:

| Secret file | 用途 | Container 内 path |
| --- | --- | --- |
| `secrets/db_password.txt` | MariaDB の WordPress user password | `/run/secrets/db_password` |
| `secrets/wp_admin_password.txt` | WordPress admin password | `/run/secrets/wp_admin_password` |
| `secrets/wp_editor_password.txt` | WordPress editor password | `/run/secrets/wp_editor_password` |

`srcs/.env` と `secrets/` の中身は Git に commit しません。

WordPress を一度 install した後に secret file を変更しても、既存 user の password や
`wp-config.php` は自動更新されません。clean reset したい場合は、永続化 data を削除して起動し直します。

## サービスが正しく動いているか確認

container status:

```sh
docker compose -f srcs/docker-compose.yml ps
```

Makefile shortcut:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

HTTPS check:

```sh
make curl-https
```
ブラウザを開かなくてもTLS接続ができるか確認できます。

直接 TLS を確認:

```sh
openssl s_client -connect 127.0.0.1:443 -tls1_1 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```

説明:

- HTTPS は NGINX が担当します。
- Compose で host に publish しているのは `443` だけです。
- NGINX で許可している TLS version は `TLSv1.2` と `TLSv1.3` です。
- 証明書は自己署名です。
