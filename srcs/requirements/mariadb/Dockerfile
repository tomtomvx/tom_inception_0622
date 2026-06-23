# ベースイメージ: penultimate stable version
# 根拠: https://alpinelinux.org/releases/
# https://hub.docker.com/_/alpine/tags
# docker run --rm alpine:latest cat /etc/alpine-release

FROM alpine:3.23

# データの保存場所を一括管理
ENV MYSQL_DATA_DIR=/var/lib/mysql \
    MYSQL_RUN_DIR=/run/mysqld


# 1. パッケージのインストール
# 根拠: https://wiki.alpinelinux.org/wiki/MariaDB
# レイヤーを統合し、キャッシュを残さないことでイメージサイズを最小化します
RUN apk add \
        mariadb \
        mariadb-client

# 2. 環境の準備 ランタイムディレクトリの作成
# mariadbd が PID 1 として動作する際に必要
RUN mkdir -p ${MYSQL_RUN_DIR} ${MYSQL_DATA_DIR} && \
    chown -R mysql:mysql ${MYSQL_RUN_DIR} ${MYSQL_DATA_DIR}
# The datadir located at /var/lib/mysql must be owned by the mysql user and group.

# 3. 設定ファイルのコピー
# コピー元を確認したい場合は、cat /vagrant/srcs/requirements/mariadb/conf/zaphod-mariadb.cnf
COPY conf/zaphod-mariadb.cnf /etc/my.cnf.d/zaphod-mariadb.cnf

# 4. エントリポイントスクリプトのコピー
COPY tools/entrypoint.sh /
RUN chmod +x /entrypoint.sh

# MariaDB のデフォルトポート
EXPOSE 3306

# コンテナ起動時の実行コマンド
ENTRYPOINT ["/entrypoint.sh"]
