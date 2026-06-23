#!/bin/sh

# 初期化ガード: mysql システムテーブルが未作成の場合のみ実行
if [ ! -d "/var/lib/mysql/mysql" ]; then
	mariadb-install-db \
		--user=mysql \
		--datadir=${MYSQL_DATA_DIR} \
		--basedir=/usr


	# 一時起動: ソケット経由のみ受け付け（TCP無効）
	# & をつけてバックグラウンドで起動する
	mariadbd --user=mysql --skip-networking &

	# MariaDB が起動するまで待機
	# mariadb-admin ping が成功するまでループ
	# --silent: エラー出力を抑制
	# タイムアウト対策: ループ回数に上限を設ける
	i=0
	while ! mariadb-admin ping --silent; do
		i=$((i + 1))
		if [ $i -gt 42 ]; then
			echo "MariaDB did not start in time" >&2
			exit 1
		fi
		sleep 1
	done

	# secrets からパスワードを読み取り
	MARIADB_PASSWORD=$(cat /run/secrets/db_password | tr -d '\n')

	mariadb --user root <<EOF
	DELETE FROM mysql.user WHERE User='';
	DROP DATABASE IF EXISTS test;
	DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
	CREATE DATABASE IF NOT EXISTS $MARIADB_DATABASE;
	CREATE USER IF NOT EXISTS '$MARIADB_USER'@'%' IDENTIFIED BY '$MARIADB_PASSWORD';
	GRANT ALL PRIVILEGES ON $MARIADB_DATABASE.* TO '$MARIADB_USER'@'%';
	FLUSH PRIVILEGES;
EOF
	# 一時起動をシャットダウン (バックグラウンドで起動した mariadbd を停止)
	# バックグラウンドで起動した mariadbd は、PID 1 ではないため、mariadb-admin コマンドを使用して安全に停止する必要がある
	# PID 1 以外のプロセスは、外部からのシグナルを受け取ることができないため、mariadb-admin コマンドを使用して MariaDB サーバーを安全に停止する必要がある
	# mariadb-admin は MariaDB サーバーを管理するためのコマンドラインツール
	# shutdown コマンドは MariaDB サーバーを安全に停止するために使用される
	# ループで起動確認した後、初期設定を行い、最後にサーバーを停止してから本番起動する流れ
	mariadb-admin --user=root shutdown
fi

# 本番起動(PID 1 として)
exec mariadbd --user=mysql
