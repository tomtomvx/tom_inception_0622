# USER_DOC.md - Inception User Documentation

このドキュメントは、Inception スタックを使うエンドユーザーまたは管理者向けの説明です。レビュー中の確認メモとしても使えるように、サービスの役割、起動・停止、アクセス、認証情報、動作確認をまとめています。

## 1. このスタックが提供するサービス

このプロジェクトは Docker Compose で 3 つのコンテナを起動し、WordPress サイトを HTTPS で提供します。

| サービス | コンテナ名 | 役割 | 外部公開 |
|---|---|---|---|
| NGINX | `nginx` | HTTPS の入口。TLS を終端し、PHP リクエストを WordPress に渡す | `443:443` |
| WordPress + PHP-FPM | `wordpress` | WordPress 本体と PHP 実行環境。`wp-cli` で初期設定する | なし |
| MariaDB | `mariadb` | WordPress の投稿、ユーザー、コメント、設定を保存する DB | なし |

通信の流れ:

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

ポイント:

- 外部に公開されるのは NGINX の `443` 番だけです。
- WordPress と MariaDB は Docker の内部ネットワーク `network_cake` で通信します。
- WordPress ファイルと MariaDB データは `/home/tvaroux/data/` 配下に永続化されます。
- パスワードは `.env` ではなく Docker secrets として `/run/secrets/` にマウントされます。

## 2. 起動と停止

コマンドはリポジトリルート、つまり `Makefile` がある場所で実行します。

```sh
cd /home/tvaroux/Desktop/inception/tom_inception_0622
```

起動:

```sh
make up
```

`make up` は `docker compose -f ./srcs/docker-compose.yml up --detach --build` を実行します。必要ならイメージをビルドし、コンテナをバックグラウンドで起動します。

停止:

```sh
make down
```

コンテナを停止して削除します。イメージ、Docker volume、ホスト側データは残ります。

ボリュームも削除して停止:

```sh
make down-v
```

Docker volume を削除します。ただし、このプロジェクトでは volume の実体が `/home/tvaroux/data/mariadb` と `/home/tvaroux/data/wordpress` に bind mount されているため、完全初期化したい場合はホスト側データも確認してください。

再起動:

```sh
make re
```

ビルドだけ:

```sh
make build
```

既存イメージで起動:

```sh
make up-no-build
```

## 3. Web サイトと管理画面へのアクセス

通常のアクセス先:

```text
https://tvaroux.42.fr
```

ローカル確認:

```text
https://127.0.0.1
```

WordPress 管理画面:

```text
https://tvaroux.42.fr/wp-admin
```

ローカル確認:

```text
https://127.0.0.1/wp-admin
```

自己署名証明書を使っているため、ブラウザで警告が出ることがあります。これはこの課題では想定内です。

## 4. 認証情報の場所と管理

機密ではない設定は `srcs/.env` にあります。

現在このプロジェクトで使う主な設定:

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

パスワードは `secrets/` 配下のファイルで管理します。

Compose が参照する secret ファイル:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_editor_password.txt
```

コンテナ内では以下のように見えます。

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_editor_password
```

管理上の注意:

- `srcs/.env` にはユーザー名、ドメイン名、DB 名などの非機密情報だけを置きます。
- パスワードは secret ファイルに置き、Git にコミットしません。
- WordPress 初回インストール後に secret の WordPress パスワードを変更しても、既存ユーザーのパスワードは自動更新されません。管理画面または `wp-cli` で変更します。
- `db_password` を変更した場合、既存の `wp-config.php` には自動反映されません。永続データを残したまま変える時は `wp-config.php` 側も更新が必要です。

## 5. サービスの動作確認

コンテナの状態:

```sh
docker compose -f srcs/docker-compose.yml ps
```

Makefile から個別確認:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

HTTPS の確認:

```sh
make curl-https
```

または:

```sh
curl --insecure --verbose https://127.0.0.1/
```

TLS バージョン確認:

```sh
openssl s_client -connect tvaroux.42.fr:443 -tls1_2 </dev/null 2>&1 | grep -E "Protocol|Cipher|CONNECTED"
openssl s_client -connect tvaroux.42.fr:443 -tls1_3 </dev/null 2>&1 | grep -E "Protocol|Cipher|CONNECTED"
```

ログ確認:

```sh
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

WordPress ユーザー確認:

```sh
docker exec wordpress wp --allow-root --path=/var/www/html user list
```

MariaDB に WordPress のデータがあるか確認:

```sh
docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SHOW TABLES;"'
```

投稿、コメント、ユーザーを確認:

```sh
docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SELECT ID, post_title, post_status, post_type FROM wp_posts WHERE post_type = '\''post'\'';"'

docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SELECT comment_ID, comment_author, comment_content, comment_approved FROM wp_comments;"'

docker exec --interactive --tty mariadb sh -c \
  'mariadb -u"$MARIADB_USER" -p"$(cat /run/secrets/db_password)" "$MARIADB_DATABASE" -e "SELECT ID, user_login, user_email FROM wp_users;"'
```

レビューで説明する要点:

- `SHOW TABLES;` で `wp_posts`, `wp_users`, `wp_options` などが見えれば WordPress DB は初期化済みです。
- ブラウザでコメントや投稿を追加した後、SQL で同じ内容を確認できます。
- コンテナを作り直しても `/home/tvaroux/data/` のデータが残っていれば WordPress の内容は永続化されます。
