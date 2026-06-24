#!/bin/sh

# 0.secrets からパスワードを読み取り　wordpress起動の度に必要なため
MARIADB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')

# 1. MariaDB が起動するまで待機
# mariadb-admin ping が成功するまでループ
# --silent: エラー出力を抑制
# タイムアウト対策: ループ回数に上限を設ける

i=0
while true; do

	# NOTE: mariadb-admin ping は到達性だけでなく認証可否も含めて成功/失敗する。
	#       db_password の不整合時はここでタイムアウトして起動を止める。
	mariadb-admin ping \
		--host=mariadb \
		--port="${MARIADB_PORT:-3306}" \
		--user="$MARIADB_USER" \
		--password="$MARIADB_PASSWORD" \
		--silent
	PING_RESULT=$?
	if [ $PING_RESULT -eq 0 ]; then
		break
	fi

	i=$((i + 1))
	if [ $i -gt 42 ]; then
		echo "MariaDB did not start in time" >&2
		exit 1
	fi
	sleep 1
done
echo "MariaDB is ready"

# 2. 初回起動時のみコアファイルダウンロード
# WordPressのコアファイル（PHPソースコード）をダウンロートして展開する。
# Dockerfilen で　WORKDIR /var/www/html　指定なのでフルパスは冗長だが、明示的に記載
if [ ! -f /var/www/html/wp-settings.php ]; then
	wp core download
fi

# 3. 初回 wp-config.php 生成
# WordPressコンテナが、MariaDBコンテナを使うための設定

# NOTE: wp-config.php は初回生成のみ（既存ファイルは上書きしない）。
#       secrets の db_password 変更は自動反映されないため、別途更新が必要。
# config.php は、MariaDB を使用するための設定ファイルであり、初回生成時にのみ作成されます。
# 既存のファイルは上書きされず、secrets の db_password の変更は自動的に反映されないため、
# 必要に応じて手動で更新する必要があります。
if [ ! -f wp-config.php ]; then
	wp config create \
		--dbhost="mariadb:${MARIADB_PORT:-3306}" \
		--dbname="${MARIADB_DATABASE}" \
		--dbuser="${MARIADB_USER}" \
		--dbpass="${MARIADB_PASSWORD}"
fi

# 4. コアファイルを元にデータベースにWordPressのテーブルを作成し、サイトの初期設定を登録する
# （URL, タイトル、管理者アカウント、編集者アカウント）
# NOTE: wp core install は初回実行時のみ（既存のテーブルがある場合はスキップ）。
#       secrets の db_password 変更は自動反映されないため、別途更新が必要。
# NOTE: 初回インストール時のみユーザー作成する。
#       既存ユーザーのパスワードは secrets 変更だけでは更新されない。
if ! wp core is-installed; then
	# secrets からパスワードを読み取り
	WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password | tr -d '\n')
	WP_USER_PASSWORD=$(cat /run/secrets/wp_editor_password | tr -d '\n')

	wp core install \
	--url=$DOMAIN_NAME \
	--title="Inception" \
	--admin_user=$WP_ADMIN_USER \
	--admin_password=$WP_ADMIN_PASSWORD \
	--admin_email=$WP_ADMIN_EMAIL

	wp user create \
		$WP_USER \
		$WP_USER_EMAIL \
		--role=editor \
		--user_pass=$WP_USER_PASSWORD
fi

# 5. PHP-FPMをファオグラウンドで起動
# php-fpmはデフォルトがデーモンなので明示的に-Fが必要。下記で確認。
# docker run  --rm php:8.3-fpm-alpine php-fpm --help

exec php-fpm83 -F
