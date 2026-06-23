#!/bin/bash

mkdir -p /var/www/html
cd /var/www/html

# WordPressが未インストールの場合のみ実行
if [ ! -f /var/www/html/wp-config.php ]; then

	# WPダウンロード
	wp core download --allow-root --locale=ja

	# wp-config.php生成
	wp config create --allow-root \
		--dbname=${MYSQL_DATABASE} \
		--dbuser=${MYSQL_USER} \
		--dbpass=${MYSQL_PASSWORD} \
		--dbhost=mariadb

	wp core install --allow-root \
		--url=https://${DOMAIN_NAME} \
		--title="Inception" \
		--admin_user=${WP_ADMIN_USER} \
		--admin_password=${WP_ADMIN_PASSWORD} \
		--admin_email=${WP_ADMIN_EMAIL} \
		--skip-email

	# 一般ユーザー追加
	wp user create --allow-root \
		${WP_USER} ${WP_USER_EMAIL} \
		--user_pass=${WP_USER_PASSWORD} \
		--role=subscriber
fi

# PHP-FPM起動（フォアグラウンド）
exec php-fpm8.2 -F