mkdir -p ../../secrets
printf 'wppassword\n' > ../../secrets/db_password
printf 'wpadminpass\n' > ../../secrets/wp_admin_password
printf 'wpeditorpass\n' > ../../secrets/wp_editor_password




docker run -d \
  --name mariadb \
  --network test-net \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wpuser \
  --mount type=bind,src="$(pwd)/../../secrets/db_password",dst=/run/secrets/db_password,readonly \
  mariadb-test:task36

  docker run -d \
  --name wordpress \
  --network test-net \
  -e DOMAIN_NAME=tvaroux.42.fr \
  -e WP_ADMIN_USER=boss42 \
  -e WP_ADMIN_EMAIL=admin@example.com \
  -e WP_USER=wpeditor \
  -e WP_USER_EMAIL=editor@example.com \
  -e MARIADB_HOST=mariadb \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wpuser \
  -e MARIADB_PORT=3306 \
  -e WP_CLI_ALLOW_ROOT=1 \
  --mount type=bind,src="$(pwd)/../../secrets/db_password",dst=/run/secrets/db_password,readonly \
  --mount type=bind,src="$(pwd)/../../secrets/wp_admin_password",dst=/run/secrets/wp_admin_password,readonly \
  --mount type=bind,src="$(pwd)/../../secrets/wp_editor_password",dst=/run/secrets/wp_editor_password,readonly \
  wordpress-test:task36

  docker logs wordpress
  
docker run -d \
  --name nginx \
  --network test-net \
  -p 443:443 \
  -p 80:80 \
  nginx-test:task36


docker exec wordpress wp --allow-root --path=/var/www/html user list



-----------------------------------------------

原因は2つです。いまの `docker run wordpress` は **secrets をマウントしていない** ので、entrypoint が読むパスワードファイルがありません。

```txt
cat: can't open '/run/secrets/db_password': No such file or directory
cat: can't open '/run/secrets/wp_admin_password': No such file or directory
cat: can't open '/run/secrets/wp_editor_password': No such file or directory
```

さらに `MARIADB_HOST` を渡していないので、`wp config create` が DB host を正しく設定できず、MariaDB ではなくローカル socket を見に行っています。

```txt
Error: Database connection error (2002) No such file or directory
```

`srcs/requirements` にいる前提で、いったん作り直すならこれです。

```sh
docker rm -f wordpress mariadb nginx
docker network rm test-net
docker network create test-net
```

secrets を用意：

```sh
mkdir -p ../../secrets
printf 'wppassword\n' > ../../secrets/db_password
printf 'wpadminpass\n' > ../../secrets/wp_admin_password
printf 'wpeditorpass\n' > ../../secrets/wp_editor_password
```

MariaDB 起動：

```sh
docker run -d \
  --name mariadb \
  --network test-net \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wpuser \
  --mount type=bind,src="$(pwd)/../../secrets/db_password",dst=/run/secrets/db_password,readonly \
  mariadb-test:task36
```

WordPress 起動：

```sh
docker run -d \
  --name wordpress \
  --network test-net \
  -e DOMAIN_NAME=tvaroux.42.fr \
  -e WP_ADMIN_USER=boss42 \
  -e WP_ADMIN_EMAIL=admin@example.com \
  -e WP_USER=wpeditor \
  -e WP_USER_EMAIL=editor@example.com \
  -e MARIADB_HOST=mariadb \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wpuser \
  -e MARIADB_PORT=3306 \
  -e WP_CLI_ALLOW_ROOT=1 \
  --mount type=bind,src="$(pwd)/../../secrets/db_password",dst=/run/secrets/db_password,readonly \
  --mount type=bind,src="$(pwd)/../../secrets/wp_admin_password",dst=/run/secrets/wp_admin_password,readonly \
  --mount type=bind,src="$(pwd)/../../secrets/wp_editor_password",dst=/run/secrets/wp_editor_password,readonly \
  wordpress-test:task36
```

確認：

```sh
docker logs wordpress
docker exec wordpress wp --allow-root --path=/var/www/html db check
docker exec wordpress wp --allow-root --path=/var/www/html user list
```

成功なら `db check` が通って、`boss42` と `wpeditor` が見えます。

ちなみに `-e WP_ADMIN_PASSWORD=...` や `-e MARIADB_PASSWORD=...` は、今の entrypoint ではほぼ使われません。あなたのスクリプトは `/run/secrets/...` を読む設計なので、結合テストでも secrets を mount するのが正解です。