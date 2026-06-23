# ベースイメージ: penultimate stable version
# 根拠: https://alpinelinux.org/releases/
# https://hub.docker.com/_/alpine/tags
# docker run --rm alpine:latest cat /etc/alpine-release

FROM alpine:3.23

# 1. 実行時に必要なパッケージのインストール
# 選定理由は下記参照
# dev_docs/0409php_packages.md
RUN apk add \
    # 1. 基盤
    php83 php83-fpm php83-phar \
    # 2. 通信・DB
    php83-curl php83-mysqli \
    # 3. データ形式
    php83-xml php83-dom \
    # 4. 文字処理
    php83-mbstring

# 2. インストールしたパッケージをCLIで実行できるようにする。
# wp-cli.phar を公式配布元からカレントディレクトリにダウンロード
# ダウンロードした phar が PHP で正常に動作するか確認
# 実行権限を付与し、PATH の通ったディレクトリに移動して `wp` コマンドとして使えるようにする
# 0200_nginx_pre_quiz_inception.mdに詳しく書いてある！
RUN apk add curl
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
&& php83 wp-cli.phar --info \
&& chmod +x wp-cli.phar \
&& mv wp-cli.phar /usr/local/bin/wp

# 3.　作業（WordPressファイルを置くところ）の作成と指定
RUN mkdir -p /var/www/html && chown -R nobody:nobody /var/www/html
WORKDIR /var/www/html

# 4. 設定ファイルのコピー
COPY  conf/www.conf /etc/php83/php-fpm.d/
# PHP の設定で memory_limit を上げる（wp-cli と同じ php83 が読む場所に置く）
COPY conf/docker-php-memlimit.ini /etc/php83/conf.d/
COPY tools/entrypoint.sh /
RUN chmod +x /entrypoint.sh

# 4-1. entrypoint.shでmariadb-admin pingするためにインストール
RUN apk add mariadb-client

# 5. コンテナ起動時の実行コマンド
ENTRYPOINT ["/entrypoint.sh"]
