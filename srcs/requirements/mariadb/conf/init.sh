#!/bin/bash

mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# 初期化ガード: mysql システムテーブルが未作成の場合のみ実行
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
fi

# 一時起動: ソケット経由のみ受け付け（TCP無効）
mysqld --user=mysql --skip-networking --socket=/var/run/mysqld/mysqld.sock &
MYSQL_PID=$!
sleep 5

# 初期設定: root パスワード、データベース、ユーザーの作成
mysql --socket=/var/run/mysqld/mysqld.sock -u root --skip-password <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

# 一時 mysqld を停止してから、正式に起動
kill $MYSQL_PID
wait $MYSQL_PID 2>/dev/null || true
sleep 2

# 最終的な mysqld の起動: TCP/IP で全てのインターフェースをリッスン
exec mysqld --user=mysql --bind-address=0.0.0.0
