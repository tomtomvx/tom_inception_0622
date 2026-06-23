# ベースイメージ: penultimate stable version
# 根拠: https://alpinelinux.org/releases/
# https://hub.docker.com/_/alpine/tags
# docker run --rm alpine:latest cat /etc/alpine-release

FROM alpine:3.23

# 課題で要求されているプロトコルがHTTPSであるため、
# TLS通信を行うための証明書と秘密鍵を生成する必要があります。
# 暗号化のためにopenSSLを使用して、自己署名証明書を生成します。 

# 環境変数を利用して、証明書と鍵の保存場所を一元管理します。
ENV SSL_DIR=/etc/nginx/ssl

# 1. 実行時に必要なパッケージ（TLS 用 openssl と Web サーバ）のインストール
# 根拠（Alpine）: https://wiki.alpinelinux.org/wiki/Nginx
# NGINX 公式ドキュメント（挙動・設定の一次資料）:
#   https://nginx.org/en/docs/beginners_guide.html
#   https://nginx.org/en/docs/http/ngx_http_ssl_module.html
#   https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
RUN apk add \
        nginx \
        openssl

# 2. 証明書・鍵の置き場所を先に用意
# 証明書と鍵を保存するディレクトリを作成します。
# これは、後のステップで証明書と鍵を生成する際に必要です。
# 例えば、openssl コマンドで証明書を生成する際に、出力先としてこのディレクトリを指定します。
RUN mkdir -p ${SSL_DIR}

# 3. 秘密鍵 (Private Key) の生成
# openssl コマンドを使用して、2048ビットのRSA秘密鍵を生成します。
# 生成された秘密鍵は、${SSL_DIR}/tvaroux_server.key に保存されます。
# この秘密鍵は、後のステップで証明書署名要求（CSR）を生成する際に使用されます。
RUN openssl genrsa -out ${SSL_DIR}/tvaroux_server.key 2048

# 4. 証明書署名要求 (CSR) の生成
# 秘密鍵を元に、「この内容で証明書を作って」という申請書を作る
# CSRは、証明書を発行するための申請書であり、公開鍵と識別情報を含みます。
# CSRを生成する際には、秘密鍵を使用して署名を行います。
RUN openssl req -new \
# 公開鍵を含むCSRを生成するために、秘密鍵を指定します。
-key ${SSL_DIR}/tvaroux_server.key \
# CSRに含める識別情報を指定します。ここでは、国（C）、都道府県（ST）、市区町村（L）、組織名（O）、組織単位名（OU）、共通名（CN）を指定しています。 
-subj "/C=JP/ST=Tokyo/L=Shinjukuku/O=42Tokyo/OU=42cursus/CN=tvaroux" \
# CSRの出力先を指定します。
-out ${SSL_DIR}/tvaroux_server.csr

# 5. 自己署名証明書の生成
# 自己署名証明書 (CRT) の発行
# 本来は認証局(CA)に送るCSRを、自分の秘密鍵で承認して証明書にする
RUN openssl x509 -req -days 365 \
# CSRを使用して証明書を生成するために、CSRの入力先を指定します。
    -in ${SSL_DIR}/tvaroux_server.csr \
# 秘密鍵を使用して証明書に署名するために、秘密鍵の場所を指定します。
    -signkey ${SSL_DIR}/tvaroux_server.key \
# 証明書の出力先を指定します。生成された証明書は、${SSL_DIR}/tvaroux_server.crt に保存されます。
    -out ${SSL_DIR}/tvaroux_server.crt

# 6. 設定ファイルのコピー
COPY conf/zzz-nginx.conf /etc/nginx/nginx.conf

# 7. ポートの公開　
# ドキュメント用。実際の公開は compose の ports 側
# NGINXのデフォルトのHTTPSポートである443番ポートを公開します。
EXPOSE 443

# 8. コンテナ起動時の実行コマンド
# NGINXをフォアグラウンドで起動するためのコマンドを指定します。
# NGINXはデフォルトでデーモンとしてバックグラウンドで動作するため、
# コンテナ内でプロセスが終了してしまうのを防ぐために、
# "-g 'daemon off;'" オプションを使用してフォアグラウンドで実行します。
# -g オプションは、Nginxのグローバル設定を指定するために使用されます。
# ここでは、"daemon off;" という設定を指定して、Nginxがデーモンとして動作しないようにしています。
ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
# デバッグ時にdocker run myimage hoge.shなどで上書してテストする場合は、CMDを使用する
# CMD ["nginx", "-g", "daemon off;"]
