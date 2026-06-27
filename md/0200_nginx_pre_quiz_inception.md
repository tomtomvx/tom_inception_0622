# Inception NGINX 事前クイズ

---

## Q1. TLS と SSL の違い

TLS（Transport Layer Security）とは何か、SSL（Secure Sockets Layer）との違いを説明してください。

**自分の回答：**

- SSLはNetscapeが開発した暗号化プロトコルだが脆弱性が発見されたため廃止された
- TLSはSSLをIETFが標準化・改良した後継規格
- 現在はTLS1.2とTLS1.3が使われている
- 現在、日常的に『SSL』と呼ばれているものの実態はTLSである

**正解：**
回答は正確です。補足として:
- SSL 2.0/3.0 は1996年に POODLE 攻撃などの脆弱性が発見され廃止
- TLS 1.0 は1999年、TLS 1.1 は2006年、TLS 1.2 は2008年、TLS 1.3 は2018年に標準化
- 現在「SSL証明書」と呼ばれているものは実際には TLS で使用される証明書

**解説：**
「SSL」という用語は歴史的な理由で今も広く使われていますが、技術的には TLS が正しい名称です。Inception 課題でも「TLSv1.2/1.3 のみ」と指定されており、SSL は使用しません。

**一次資料：**
- [RFC 8446 - The Transport Layer Security (TLS) Protocol Version 1.3](https://datatracker.ietf.org/doc/html/rfc8446)
- [RFC 5246 - The Transport Layer Security (TLS) Protocol Version 1.2](https://datatracker.ietf.org/doc/html/rfc5246)
- [SSL 3.0 deprecation - RFC 7568](https://datatracker.ietf.org/doc/html/rfc7568)


---

## Q2. TLSv1.2 と TLSv1.3 の違い

TLSv1.2 と TLSv1.3 の主な違いを3つ挙げてください。

**自分の回答：**

	① ハンドシェイクの速さ：v1.3は1-RTT（往復1回）、v1.2は2-RTT。v1.3の方が接続が速い。

	② 廃止された古い暗号方式：v1.3はRC4やSHA-1など脆弱な暗号を仕様から完全に除外した。

	③ 0-RTTの導入：v1.3は再接続時にハンドシェイクをスキップできる（セキュリティとのトレードオフあり）。

**正解：**
3つの違いは正確です。補足として:
- **ハンドシェイク**: TLS 1.3 は暗号スイート交渉を簡素化し、1-RTT で完了
- **暗号スイート**: TLS 1.3 は5つの暗号スイートのみサポート（1.2 は37個）
- **0-RTT**: 再接続時のパフォーマンス向上だが、リプレイ攻撃のリスクあり

**解説：**
TLS 1.3 は「セキュリティの向上」と「パフォーマンスの改善」の両方を実現しています。Inception では両バージョンをサポートしますが、最新のブラウザは TLS 1.3 を優先的に使用します。

**一次資料：**
- [RFC 8446 - TLS 1.3 (Section 1.2 - Major Differences from TLS 1.2)](https://datatracker.ietf.org/doc/html/rfc8446#section-1.2)
- [Cloudflare - TLS 1.3 Overview](https://www.cloudflare.com/learning/ssl/why-use-tls-1.3/)
---

## Q3. 自己署名証明書とは

自己署名証明書（self-signed certificate）とは何か、認証局（CA）発行の証明書との違いを説明してください。

**自分の回答：**

- 署名証明書:暗号化に必要な公開鍵の作成者（通信先のサイト）が誰であるかを証明できるテキストファイル。
- 自己署名証明書（self-signed certificate）:自分が作ったサイトの安全性を自分で証明書する書類であり無料で誰でも作れる。この証明書を見たユーザーがそれを信頼するかどうかはユーザー次第。インターネットと繋がっていないイントラネットや、学習用やテスト用に使われることが多い。
- 認証局（CA）発行の証明書：第三者機関である承認局が安全性を確認して承認していて有料の場合もある？

**正解：**
回答は正確です。補足として:
- **自己署名証明書**: 発行者（Issuer）と対象者（Subject）が同一
- **CA発行証明書**: 信頼されたルート CA の署名チェーンにより信頼性を検証可能
- **証明書の内容**: 公開鍵、有効期限、ドメイン名、署名アルゴリズム等を含む

**解説：**
自己署名証明書は「信頼の起点」が自分自身であるため、ブラウザは警告を表示します。Inception 課題では学習目的のため自己署名証明書を使用しますが、本番環境では Let's Encrypt などの CA 発行証明書を使用すべきです。

証明書は X.509 形式で、以下の情報を含みます:
- Version（バージョン）
- Serial Number（シリアル番号）
- Signature Algorithm（署名アルゴリズム）
- Issuer（発行者）
- Validity（有効期限）
- Subject（対象者）
- Public Key（公開鍵）
- Extensions（拡張情報）

**一次資料：**
- [RFC 5280 - X.509 Public Key Infrastructure Certificate](https://datatracker.ietf.org/doc/html/rfc5280)
- [OpenSSL Documentation - x509](https://www.openssl.org/docs/man3.0/man1/openssl-x509.html)


---

## Q4. 自己署名証明書の作成コマンド

`openssl` コマンドで自己署名証明書を作成する際、最低限必要なファイルは何か、また生成コマンドの基本構文を書いてください。

**自分の回答：**
- その出所を証明する必要がある秘密鍵ファイル
- 作成する証明書の名前がついたファイル
秘密鍵の作成:`openssl x509 genrsa -out tvaroux.key 2048`
証明書署名要求:`openssl x509 req -out tvaroux.csr -key tvaroux.key -new`
証明書の内容確認(念の為):`openssl x509 -in tvaroux.crt -text -noout`

**正解：**
最低限必要なファイルは以下の2つ:
1. **秘密鍵ファイル**（例: `server.key`）
2. **証明書ファイル**（例: `server.crt`）

基本的な生成コマンド（1コマンドで秘密鍵 + 証明書を同時生成）:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout server.key -out server.crt \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=42Tokyo/CN=toruinoue.42.fr"
```
または、段階的に生成する場合:
```bash
# 1. 秘密鍵の生成
openssl genrsa -out server.key 2048

# 2. CSR（証明書署名要求）の生成
openssl req -new -key server.key -out server.csr \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=42Tokyo/CN=toruinoue.42.fr"

# 3. 自己署名証明書の生成
openssl x509 -req -days 365 -in server.csr \
  -signkey server.key -out server.crt
```

一次資料：

- https://www.openssl.org/docs/man3.0/man1/openssl-req.html
- https://www.openssl.org/docs/man3.0/man1/openssl-genrsa.html
- https://www.openssl.org/docs/man3.0/man1/openssl-x509.html
---

## Q5. リバースプロキシとは

リバースプロキシ（reverse proxy）とは何か、フォワードプロキシとの違いを含めて説明してください。

**自分の回答：**

- リバースプロキシ（reverse proxy）とはブラウザ側からバックエンド（のポート番号）を隠す代理サーバー。
- フォワードプロキシはサーバー側からクライアント（のIPアドレスとポート番号）を隠す代理サーバー


### Q5（正解）

**正解：**
回答は正確です。補足として:
- **フォワードプロキシ:** クライアント → プロキシ → インターネット（クライアントの代理）
- **リバースプロキシ:** インターネット → プロキシ → バックエンド（サーバーの代理）

**解説：**
リバースプロキシの主な役割:
1. **TLS 終端**: HTTPS の暗号化・復号を一箇所で処理
2. **負荷分散**: 複数のバックエンドサーバーへリクエストを振り分け
3. **キャッシング**: 静的コンテンツをキャッシュしてバックエンドの負荷を軽減
4. **セキュリティ**: バックエンドを外部から隠蔽

Inception では NGINX が TLS 終端とプロトコル変換（HTTP → FastCGI）を担当します。

**一次資料：**
- [NGINX Documentation - Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [RFC 7230 - HTTP/1.1: Message Syntax and Routing (Section 2.3 - Intermediaries)](https://datatracker.ietf.org/doc/html/rfc7230#section-2.3)

---

## Q6. NGINX がリバースプロキシとして動作する理由

Inception 課題で NGINX がリバースプロキシとして動作する理由を、WordPress + PHP-FPM の構成と関連付けて説明してください。

**自分の回答：**
- WordPressはPHP-FPMエンジンにより動的にHTMLを生成するプログラムであり、HTTP、HTTPSを受け取る機能は持っていない。
- ブラウザとのHTTPS通信はNGINXが担いブラウザからのリクエストをFastCGIに変換してPHP-FPMに渡す。このPHP-FPMブラウザとHTTPS通信を行える。NGINXはPHP-FPMが外部公開されているWebサーバーでないので接続先のポートを隠すことができる。
- まとめると

	① TLS終端：
	ブラウザとのHTTPS暗号化・復号をNGINXが担う。WordPressはHTTPSを処理できない。

	② プロトコル変換：NGINXがHTTPSリクエストをFastCGIに変換してPHP-FPMへ渡す。
	
	③ 窓口の一元化：外部に公開するのはNGINXのポート443だけ。WordPressは外部から直接見えない。

**正解：**
回答は非常に正確で、3つのポイントがよくまとまっています。

**解説：**
WordPress 自体は PHP で書かれたアプリケーションであり、HTTP サーバー機能を持ちません。そのため:
- **PHP-FPM**: FastCGI プロトコルで PHP を実行（ポート 9000 で待機）
- **NGINX**: HTTP/HTTPS を受け取り、FastCGI に変換して PHP-FPM へ転送

この構成により、NGINX と PHP-FPM を独立してスケールできる利点もあります。

通信フロー:
---

## Q7. fastcgi_pass とは

NGINX の設定ディレクティブ `fastcgi_pass` とは何か、どのような場面で使用されるかを説明してください。

**自分の回答：**

- NGINXの設定ファイルに書く命令（ディレクティブ）の一つで、
- .phpへのリクエストをどのFastCGIサーバー（ホスト名:ポート）に転送するかを指定する。
- Inceptionでは`fastcgi_pass wordpress:9000;`と書く。

**正解：**
回答は正確です。

**解説：**
`fastcgi_pass` は NGINX が FastCGI サーバーへリクエストを転送する際の宛先を指定します。

指定方法:
- **TCP ソケット**: `fastcgi_pass wordpress:9000;`（Inception で使用）
- **Unix ソケット**: `fastcgi_pass unix:/var/run/php-fpm.sock;`（同一ホスト内で高速）

Inception では Docker network を使用するため、TCP ソケット + サービス名解決を使います。

**一次資料：**
- [NGINX Documentation - ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_pass)

---

## Q8. FastCGI プロトコル

FastCGI プロトコルとは何か、CGI との違いを説明してください。

**自分の回答：**
- CGIはComon Gateway Interfaceの略でWeb上でPHPプログラムを動かす仕組みのことで、ブラウザからPHPファイルへのリクエストのたびにPHPプロセスを起動・終了するために遅い。
- FastCGIはPHPプロセスをメモリ上に常駐させておき、リクエストのたびにそのプロセスを使い回す（呼び出す）ための技術全体（プロトコル+仕組み）を指す言葉である
- PHP-FPMはFastCGIが呼び出す対象となるプロセスをOSレベルで管理するツールで、Inceptionではwordpressコンテナ内のポート9000で待機している。
- FastCGI プロトコルはFastCGI を実現するための通信規約

**正解：**
回答は非常に正確です。補足として:
- **CGI**: リクエストごとにプロセスを fork → 実行 → 終了（遅い）
- **FastCGI**: プロセスプールを常駐させ、リクエストを使い回す（速い）
- **PHP-FPM**: FastCGI Process Manager の略で、PHP 専用の FastCGI 実装

**解説：**
FastCGI はプロトコル仕様（RFC 3875 の拡張）であり、PHP-FPM はその実装の一つです。他の言語でも FastCGI 実装があります（Python の flup、Ruby の fcgi など）。

Inception では:
- NGINX が FastCGI クライアント
- PHP-FPM が FastCGI サーバー

**一次資料：**
- [FastCGI Specification](https://fastcgi-archives.github.io/FastCGI_Specification.html)
- [PHP-FPM Documentation](https://www.php.net/manual/en/install.fpm.php)
- [RFC 3875 - The Common Gateway Interface (CGI) Version 1.1](https://datatracker.ietf.org/doc/html/rfc3875)

---

## Q9. NGINX 設定ファイルの基本構造

NGINX の設定ファイル（nginx.conf）の基本構造を、以下のディレクティブの階層関係を含めて説明してください:
- `events`
- `http`
- `server`
- `location`

**自分の回答：**
- 下記に例示する
```nginx
＃グローバル設定
worker_processes 1;

events {
	＃接続処理の設定
	worker_connections 1024;
}

http {
	＃HTTP通信全体の設定
	server {
		＃　バーチャルホスト一つ分の設定
		location / {
			＃URLパスごとの設定
		}
		location ~\.php${
			＃URLパスごとの設定
		}
	}
}
```
- `events`と`http`は同じ階層に書かれる
- `server`は`http`の中だけに書ける
- `location`は`server`の中だけに書ける
- `location`の中に`location`をネストすることは可能

**正解：**
回答は正確で、具体例も素晴らしいです。

**解説：**

NGINX の設定ファイルは「コンテキスト」という階層構造を持ちます:

	main context（グローバル）
 	├── events context（接続処理） 
  	└── http context（HTTP全体） 
	 		└── server context（バーチャルホスト）
			└── location context（URLパスごと）
	    			└── location context（ネスト可能）


ディレクティブは、それが記述できるコンテキストが決まっています。例えば:
- `worker_processes`: main のみ
- `worker_connections`: events のみ
- `listen`: server のみ
- `fastcgi_pass`: location のみ

**一次資料：**
- [NGINX Documentation - Configuration File Structure](https://nginx.org/en/docs/beginners_guide.html#conf_structure)
- [NGINX Documentation - Alphabetical index of directives](https://nginx.org/en/docs/dirindex.html)
---

## Q10. location ブロックの優先順位

NGINX の `location` ブロックには複数のマッチングパターン（`=`, `~`, `~*`, `^~`, prefix）があります。これらの優先順位を説明してください。

**自分の回答：**
`=` >  `^~` > `~` = `~*`

**正解：**
完全な優先順位は以下の通り:

1. **`=`**（完全一致）: `location = /path`
2. **`^~`**（前方一致、正規表現より優先）: `location ^~ /images/`
3. **`~`**（正規表現、大文字小文字区別）: `location ~ \.php$`
4. **`~*`**（正規表現、大文字小文字無視）: `location ~* \.(jpg|png)$`
5. **prefix**（前方一致）: `location /docs/`

あなたの回答 `=` > `^~` > `~` = `~*` は正しいですが、**prefix が抜けています**。

**解説：**
マッチング処理の流れ:
1. `=` で完全一致を探す → 見つかれば即座に採用、終了
2. prefix（`^~` と通常の prefix）で最長一致を探す
   - `^~` が最長一致なら採用、終了
   - 通常の prefix が最長一致なら記憶して次へ
3. `~` / `~*` を上から順に評価 → 最初にマッチしたものを採用、終了
4. 正規表現にマッチしなければ、手順2で記憶した prefix を採用

**具体例:**
```nginx
location = /exact {          # 1. /exact のみ
}
location ^~ /images/ {       # 2. /images/* で正規表現より優先
}
location ~ \.php$ {          # 3. *.php（大文字小文字区別）
}
location ~* \.(jpg|png)$ {   # 4. *.jpg, *.png（大文字小文字無視）
}
location /docs/ {            # 5. /docs/* （prefix、正規表現より後）
}
---

## Q11. try_files ディレクティブ

`try_files $uri $uri/ /index.php?$args;` という設定の動作フローを説明してください。

**自分の回答：**
- この動作フローは、「ファイル→ディレクトリ→index.phpの順に試す」という設定です。
- WordPressのURLは実ファイルが存在しないので、最終的にindex.phpに渡してWordPress側でルーティングさせるために必要です。
-  `try_files`コマンドの各引数と挙動の関係は下記の通り  
	- `$uri`ブラウザからリクセストされたパスに直接一致するファイルがあるならそれを返す
	- ` $uri/`一致するファイルがなければ、それがディレクトリとして存在するか確認、あれば`index.html`などを返す
	- ` /index.php`上記二つに該当しない場合強制的に`index.php`に丸投げする
	- `?$args` をつけることで、URLに含まれるパラメータ（例：?search=keyword）を引き継いだまま渡せる。
- Apacheの下記と等価 
```Apache
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
```

### Q11（正解）

**正解：**
回答は非常に正確で、Apache との比較も素晴らしいです。

**解説：**
WordPress は「パーマリンク」機能により、実際のファイルが存在しないURLを生成します。例えば:
- `/2024/03/hello-world/` → 実際には `/index.php?p=123` として処理

`try_files` はこのような「ファイルレス URL」を処理するために必須です。

動作例:
- リクエスト: `/wp-content/themes/style.css`
  - `$uri` → ファイルが存在 → 即座に返す
- リクエスト: `/2024/03/hello-world/`
  - `$uri` → ファイルなし
  - `$uri/` → ディレクトリなし
  - `/index.php?$args` → WordPress にルーティングを委譲

**一次資料：**
- [NGINX Documentation - try_files](https://nginx.org/en/docs/http/ngx_http_core_module.html#try_files)
- [WordPress Codex - Using Permalinks](https://wordpress.org/documentation/article/customize-permalinks/)

---

## Q12. NGINX で TLS を有効化する最低限の設定

NGINX で TLS（HTTPS）を有効化するために必要な最低限の設定ディレクティブを3つ挙げてください。

**自分の回答：**

\# 1 「ポート443で待ち受けて、SSLを有効にする」という宣言`ssl`をつけないとHTTPとして扱われる。

\# 2 サーバー証明書（公開鍵が入っている）のパスを指定します。ブラウザに渡して「このサーバーは本物ですよ」と証明するファイルです

\# 3 秘密鍵のパスを指定します。証明書とペアで必ず必要です。秘密鍵がないと暗号化通信を確立できません。
```nginx
server {
	listen 443 ssl;							#1
	ssl_certificate 	 /path/to/cert.crt	#2
	ssl_ceritificate_key /path/to/cert.key	#3
}
```
**正解：**
3つのディレクティブは正確です。補足として:
- `listen 443 ssl;` は NGINX 1.15.0 以降の構文（古いバージョンでは `listen 443; ssl on;`）
- `ssl_certificate` はサーバー証明書（公開鍵を含む）
- `ssl_certificate_key` は秘密鍵（絶対に外部に漏らしてはならない）

**解説：**
最低限の設定例:
```nginx
server {
    listen 443 ssl;
    server_name toruinoue.42.fr;
    
    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    
    # ... その他の設定
}
```
Inception では追加で以下も設定します:

ssl_protocols TLSv1.2 TLSv1.3;（セキュリティ強化）
ssl_ciphers または ssl_prefer_server_ciphers（暗号スイート制御）
**一次資料：**

- https://nginx.org/en/docs/http/configuring_https_servers.html

- https://nginx.org/en/docs/http/ngx_http_ssl_module.html
---

## Q13. ssl_protocols の設定

Inception 課題では `ssl_protocols TLSv1.2 TLSv1.3;` と設定します。なぜ TLSv1.0 や TLSv1.1 を含めないのか説明してください。

**自分の回答：**

TLSv1.0とv1.1はPOODLEなどの脆弱性が発見されており、2021年にRFCで非推奨とされた。そのためInceptionではTLSv1.2とv1.3のみを許可している


### Q13（正解）

**正解：**
回答は正確です。補足として:
- **TLSv1.0**: BEAST 攻撃（2011年）、POODLE 攻撃（2014年）
- **TLSv1.1**: RC4 暗号の脆弱性、CBC モードの問題
- **RFC 8996**（2021年3月）: TLS 1.0/1.1 を正式に廃止（Deprecated）

**解説：**
主要ブラウザの対応状況:
- Chrome 84（2020年7月）: TLS 1.0/1.1 を無効化
- Firefox 78（2020年6月）: TLS 1.0/1.1 を無効化
- Safari 14（2020年9月）: TLS 1.0/1.1 を無効化

Inception 課題では最新のセキュリティベストプラクティスに従い、TLS 1.2/1.3 のみをサポートします。

**一次資料：**
- [RFC 8996 - Deprecating TLS 1.0 and TLS 1.1](https://datatracker.ietf.org/doc/html/rfc8996)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
---

## Q14. NGINX のデフォルトポート

NGINX のデフォルトポートは何番か、また HTTPS の標準ポートは何番か答えてください。

**自分の回答：**

- HTTPのデフォルトは80番、HTTPSは443番。
- どちらもIANA（Internet Assigned Numbers Authority）が管理するウェルノウンポート
	- 80番（HTTP）：1991年にHTTP/1.0が設計された際にIANAに登録された。特に深い理由はなく「空いていた番号」
	- 443番（HTTPS）：1994年にNetscapeがSSLを開発した際にIANAに申請・登録した
- InceptionではHTTPSのみ使うので443番だけlistenに指定する

**正解：**
回答は正確で、歴史的背景まで調査されているのは素晴らしいです。

**解説：**
ポート番号の分類:
- **0-1023**: Well-Known Ports（システムポート、root 権限が必要）
- **1024-49151**: Registered Ports（登録ポート）
- **49152-65535**: Dynamic/Private Ports（動的ポート）

Inception での設定:
```nginx
server {
    listen 443 ssl;  # HTTPS のみ
    # listen 80; は設定しない（HTTP は使わない）
}
```
課題要件では「443 ポートのみ」と指定されているため、80 ポートへのリダイレクトも不要です。
**一次資料：**
- https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml

- https://datatracker.ietf.org/doc/html/rfc7230
---

## Q15. root vs alias

NGINX の `root` ディレクティブと `alias` ディレクティブの違いを、具体例を含めて説明してください。

**自分の回答：**

- rootはlocationのパスをそのまま連結する。
- aliasはlocationのパスを置き換える。root /var/www/htmlで/images/にアクセスすると/var/www/html/images/を探す


### Q15（説明が不完全）

**正解：**
基本的な理解は正しいですが、具体例が不足しています。

**`root` の動作:**
`location` のパスを**連結**します。

```nginx
location /images/ {
    root /var/www/html;
}
# /images/logo.png へのリクエスト
# → /var/www/html/images/logo.png を探す
```
**`alias` の動作:** `location` のパスを置き換えます。
```bash
location /images/ {
    alias /var/www/html/;
}
# /images/logo.png へのリクエスト
# → /var/www/html/logo.png を探す（/images/ が消える）
```
**解説：** 重要な違い:

- `root`: location のパスがファイルパスに含まれる
- `alias`: location のパスがファイルパスから除外される
- `alias` の末尾に `/` が必要（`location` も `/` で終わる場合）
Inception では WordPress のルートディレクトリを指定するため root を使用します:
```bash
location / {
    root /var/www/html;
    index index.php;
}
```
**一次資料：**
- https://nginx.org/en/docs/http/ngx_http_core_module.html#root
- https://nginx.org/en/docs/http/ngx_http_core_module.html#alias
---

## Q16. index ディレクティブ

`index index.php index.html;` という設定の意味を説明してください。

**自分の回答：**

- indexディレクティブはURLがディレクトリで終わっている場合に、最初に返すファイルの優先順位を指定する。
- 左から順に探して最初に見つかったものを返す


### Q16（正解）

**正解：**
回答は正確です。

**解説：**
`index` ディレクティブは、URL がディレクトリで終わる場合（例: `/` や `/blog/`）に返すファイルを指定します。

動作例:
```nginx
index index.php index.html;

# リクエスト: https://toruinoue.42.fr/
# 1. /var/www/html/index.php を探す → 存在すれば返す
# 2. なければ /var/www/html/index.html を探す → 存在すれば返す
# 3. どちらもなければ 404 または autoindex（ディレクトリ一覧）
```
Inception では WordPress を使用するため、`index.php` を最優先にします。

**一次資料：**
- https://nginx.org/en/docs/http/ngx_http_index_module.html#index
---

## Q17. fastcgi_param の役割

`fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;` という設定の役割を説明してください。

**自分の回答：**

- `fastcgi_param SCRIPT_FILENAME`は実行するPHPファイルのフルパスをPHP-FPMに伝えるための環境変数
-  `$document_root`  `$fastcgi_script_name`を連結してファイルパスを組み立てる


### Q17（正解）

**正解：**
回答は正確です。補足として:
- `$document_root`: `root` ディレクティブで指定したパス（例: `/var/www/html`）
- `$fastcgi_script_name`: URL から抽出されたスクリプト名（例: `/index.php`）
- 結果: `/var/www/html/index.php`

**解説：**
PHP-FPM は「どのファイルを実行すべきか」を知る必要があります。`SCRIPT_FILENAME` 環境変数がその情報を伝えます。

完全な FastCGI 設定例:
```nginx
location ~ \.php$ {
    fastcgi_pass wordpress:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;  # その他の標準パラメータ
}
```
`include fastcgi_params;` は NGINX が提供する標準的な FastCGI パラメータ（`REQUEST_METHOD`, `QUERY_STRING` など）を読み込みます。

**一次資料：**
- https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_param
- https://fastcgi-archives.github.io/FastCGI_Specification.html#S6.2

---

## Q18. Docker network とサービス名解決

`fastcgi_pass wordpress:9000;` という設定で、なぜ `wordpress` というホスト名が解決されるのか説明してください。

**自分の回答：**

- docker-compose.ymlでユーザーが定義したサービス名が、DockerのDNSに自動登録される
- このときIPアドレスはDockerが自動割り当てするためユーザーは指定できない
- 同じDockerネットワーク内のコンテナはサービス名をホスト名として使える
- このため、NGINXはwordpress:9000と書くだけでPHP-FPMコンテナのIPアドレスを意識せずに接続できる。


### Q18（正解）

**正解：**
回答は非常に正確です。

**解説：**
Docker Compose は各サービスに対して:
1. **内部 DNS サーバー**を自動的に起動（通常 `127.0.0.11`）
2. サービス名を DNS レコードとして登録
3. 同じネットワーク内のコンテナから名前解決可能にする

確認方法:
```bash
# NGINX コンテナ内から
docker exec -it nginx sh
nslookup wordpress
# → wordpress のIPアドレスが返る（例: 172.18.0.3）

cat /etc/resolv.conf
# → nameserver 127.0.0.11（Docker の内部 DNS）
```
**重要な制約:**

- サービス名解決は同じネットワーク内でのみ有効
- network_mode: host を使用すると DNS が機能しない（Inception で禁止されている理由の一つ）

**一次資料：**
- https://docs.docker.com/compose/networking/
- https://docs.docker.com/engine/network/#dns-services
---

## 今日詰まったポイント（実装メモ）

（事前クイズのため、実装はまだ行っていない）

---


## レビュー想定問答集の作成

全問の正解・解説を追記したら、最後に「レビュー想定問答集」を一緒に作成しましょう。

弱点として特に注意すべき項目:
1. **Q4**: openssl コマンドの正しい構文
2. **Q10**: location の優先順位（prefix の位置）
3. **Q15**: root と alias の具体的な違い

これらを中心に、レビューで質問されそうな内容をまとめます。
---

## レビュー想定問答集（弱点中心）

### 1. openssl コマンドの正しい構文（Q4の弱点）

**Q: 自己署名証明書を作成するコマンドを説明してください。**

A: 1コマンドで秘密鍵と証明書を同時生成する方法:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout server.key -out server.crt \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=42Tokyo/CN=toruinoue.42.fr"
```
主要オプション:

- `req`		: 証明書署名要求（CSR）または自己署名証明書を生成
- `-x509`	: CSR ではなく自己署名証明書を直接生成
- `-nodes`	: 秘密鍵を暗号化しない（パスフレーズ不要、自動起動に必須）
- `-days 365`: 有効期限を365日に設定
- `-newkey rsa:2048`: 2048ビットの RSA 秘密鍵を新規生成
-  `-keyout`: 秘密鍵の出力先
- `-out`: 証明書の出力先
- `-subj`: 証明書の Subject（対象者情報）を非対話的に指定

---
**Q: なぜ -nodes オプションが必要なのですか？**

A: -nodes は "no DES" の略で、秘密鍵を暗号化しません。
暗号化すると起動時にパスフレーズの入力が必要になり、Docker コンテナの自動起動ができなくなります。
Inception では自動起動が必須のため -nodes を使用します。

---

### 2. location の優先順位（Q10の弱点）

**Q: NGINX の location ブロックのマッチング優先順位を説明してください。**

A: 優先順位（高い順）:

	1.`=`（完全一致）: `location = /exact`
	2.`^~`（前方一致、正規表現より優先）: `location ^~ /images/`
	3.`~`（正規表現、大文字小文字区別）: `location ~ \.php$`
	4.`~*`（正規表現、大文字小文字無視）: `location ~* \.(jpg|png)$`
	5.prefix（前方一致）: location /docs/
**Q: マッチング処理の流れを説明してください。**

A:

1.`=` で完全一致を探す → 見つかれば即座に採用、終了
2.prefix（`^~` と通常の prefix）で最長一致を探す

- `^~` が最長一致なら採用、終了
- 通常の prefix が最長一致なら記憶して次へ

3.`~` / `~*` を上から順に評価 → 最初にマッチしたものを採用、終了

4.正規表現にマッチしなければ、手順2で記憶した prefix を採用

**Q: なぜ正規表現は「上から順に」評価されるのですか？**

A: 正規表現 location は設定ファイルに記述された順序で評価され、最初にマッチしたものが採用されます。そのため、より具体的なパターンを上に、汎用的なパターンを下に配置する必要があります。

例:

```bash
location ~ ^/api/v2/.*\.php$ {  # より具体的（先に評価）
    # API v2 専用の処理
}
location ~ \.php$ {              # より汎用的（後に評価）
    # 通常の PHP 処理
}
```
---

### 3. root と alias の違い（Q15の弱点）

**Q: `root` と `alias` の違いを具体例で説明してください。

A:
`root` の場合（location パスを連結）:
```bash
location /images/ {
    root /var/www/html;
}
# /images/logo.png へのリクエスト
# → /var/www/html/images/logo.png を探す
```
`alias` の場合（location パスを置き換え）:
```bash
location /images/ {
    alias /var/www/html/;
}
# /images/logo.png へのリクエスト
# → /var/www/html/logo.png を探す（/images/ が消える）
```

**Q: Inception ではどちらを使いますか？**

A: `root` を使用します。WordPress のルートディレクトリを指定するため:
```bash
location / {
    root /var/www/html;
    index index.php;
    try_files $uri $uri/ /index.php?$args;
}
```
**Q: alias を使う場合の注意点は？**

A: `alias` の末尾に `/` が必要です（`location` も `/` で終わる場合）。末尾の `/` を忘れるとパスが正しく解決されません:
```bash

# 正しい
location /images/ {
    alias /var/www/html/;
}

# 間違い（/var/www/htmllogo.png を探してしまう）
location /images/ {
    alias /var/www/html;
}
```
---
### 4. TLS の基礎（レビュー頻出）

**Q: TLS 1.2 と TLS 1.3 の主な違いを3つ挙げてください。**

A:

1. **ハンドシェイク**: TLS 1.3 は1-RTT、TLS 1.2 は2-RTT（1.3 の方が高速）
2. **暗号スイート**: TLS 1.3 は脆弱な暗号を完全に除外（RC4, SHA-1 など）
3. **0-RTT**: TLS 1.3 は再接続時にハンドシェイクをスキップ可能（セキュリティとのトレードオフあり）

**Q: なぜ TLSv1.0 と TLSv1.1 を使わないのですか？**

A: POODLE 攻撃などの脆弱性が発見されており、RFC 8996（2021年3月）で正式に廃止（Deprecated）されました。
主要ブラウザも2020年に無効化しています。Inception では最新のセキュリティベストプラクティスに従い、TLS 1.2/1.3 のみをサポートします。

**Q: 自己署名証明書と CA 発行証明書の違いは？**

A:

- **自己署名証明書**: 発行者（Issuer）と対象者（Subject）が同一。信頼の起点が自分自身。ブラウザは警告を表示。
- **CA発行証明書**: 信頼されたルート CA の署名チェーンにより信頼性を検証可能。ブラウザは警告を表示しない。
Inception では学習目的のため自己署名証明書を使用しますが、本番環境では Let's Encrypt などの CA 発行証明書を使用すべきです。
---
### 5. FastCGI の仕組み（レビュー頻出）
**Q: FastCGI と CGI の違いを説明してください。**

A:

- CGI: リクエストごとにプロセスを fork → 実行 → 終了（遅い）
- FastCGI: プロセスプールを常駐させ、リクエストを使い回す（速い）

**Q: PHP-FPM とは何ですか？**

A:
- FastCGI Process Manager の略で、PHP 専用の FastCGI 実装です。
- 複数の PHP プロセスをプールとして管理し、リクエストを効率的に処理します。
- Inception では WordPress コンテナ内のポート 9000 で待機しています。

**Q: `fastcgi_pass wordpress:9000;` で、なぜ `wordpress` というホスト名が解決されるのですか？**

A:

- Docker Compose は各サービスに対して内部 DNS サーバー（通常 `127.0.0.11`）を自動的に起動し、サービス名を DNS レコードとして登録します。
 
 - 同じネットワーク内のコンテナはサービス名をホスト名として使用できます。

重要な制約: サービス名解決は同じネットワーク内でのみ有効です。network_mode: host を使用すると DNS が機能しません（Inception で禁止されている理由の一つ）。

**Q: `fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;` の役割は？**

A: 実行する PHP ファイルのフルパスを PHP-FPM に伝えるための環境変数です。

- `$document_root: root` ディレクティブで指定したパス（例: `/var/www/html`）
- `$fastcgi_script_name`: URL から抽出されたスクリプト名（例: `/index.php`）
結果: `/var/www/html/index.php`
PHP-FPM はこの情報をもとに、どのファイルを実行すべきかを判断します。

---
### 6. リバースプロキシの役割（レビュー頻出） ###
**Q: Inception 課題で NGINX がリバースプロキシとして動作する理由を説明してください。**

A: WordPress は PHP で書かれたアプリケーションであり、HTTP サーバー機能を持ちません。そのため:

1. **TLS終端**: ブラウザとの HTTPS 暗号化・復号を NGINX が担当。WordPress は HTTPS を処理できない。
2. **プロトコル変換**: NGINX が HTTPS リクエストを FastCGI に変換して PHP-FPM へ転送。
3. **窓口の一元化**: 外部に公開するのは NGINX のポート 443 だけ。WordPress は外部から直接見えない。
通信フロー:
```
ブラウザ --[HTTPS]--> NGINX --[FastCGI]--> PHP-FPM --[SQL]--> MariaDB
                (443)               (9000)              (3306)
```

**Q: リバースプロキシとフォワードプロキシの違いは？**

A:

- **フォワードプロキシ**: クライアント → プロキシ → インターネット（クライアントの代理）
- **リバースプロキシ: インターネット** → プロキシ → バックエンド（サーバーの代理）
---
### 7. try_files の動作（レビュー頻出） ###
**Q: `try_files $uri $uri/ /index.php?$args;` の動作フローを説明してください。**

A: この設定は「ファイル→ディレクトリ→index.php の順に試す」という動作を実現します:

1. `$uri`: リクエストされたパスに直接一致するファイルがあるならそれを返す
2. `$uri/`: 一致するファイルがなければ、それがディレクトリとして存在するか確認、あれば `index.html` などを返す
3. `/index.php?$args`: 上記二つに該当しない場合、強制的に `index.php` に丸投げする。`?$args` をつけることで、URL に含まれるパラメータを引き継ぐ。

**Q: なぜこの設定が WordPress に必要なのですか？**

A:
-  WordPress は「パーマリンク」機能により、実際のファイルが存在しない URL を生成します。
- 例えば `/2024/03/hello-world/` は実際には `/index.php?p=123` として処理されます。
- `try_files` はこのような「ファイルレス URL」を処理するために必須です。

---
### 8. NGINX 設定ファイルの構造（レビュー頻出）
**Q: NGINX の設定ファイルの階層構造を説明してください。**

A:
```
main context（グローバル）
├── events context（接続処理）
└── http context（HTTP全体）
    └── server context（バーチャルホスト）
        └── location context（URLパスごと）
            └── location context（ネスト可能）
```
- `events`と `http` は同じ階層（main の直下）
- `server` は `http` の中だけに書ける
- `location` は `server` の中だけに書ける
- `location` の中に `location` をネストすることは可能

### Q: ディレクティブが記述できるコンテキストは決まっていますか？

A: はい、各ディレクティブは記述できるコンテキストが決まっています。例えば:

- `worker_processes`: main のみ
- `worker_connections`: events のみ
- `listen`: server のみ
- `fastcgi_pass`: location のみ

間違ったコンテキストに記述すると、NGINX の設定テストでエラーになります。

---
### 9. Docker network とサービス名解決（レビュー頻出） ###

**Q: Docker Compose でサービス名がホスト名として解決される仕組みを説明してください。**

A: Docker Compose は各サービスに対して:

1. 内部 DNS サーバーを自動的に起動（通常 `127.0.0.11`）
2. サービス名を DNS レコードとして登録
3. 同じネットワーク内のコンテナから名前解決可能にする
確認方法:
```bash
# NGINX コンテナ内から
docker exec -it nginx sh
nslookup wordpress
# → wordpress のIPアドレスが返る（例: 172.18.0.3）

cat /etc/resolv.conf
# → nameserver 127.0.0.11（Docker の内部 DNS）
```
**Q: なぜ `network_mode: host` が禁止されているのですか？**

A: `network_mode: host` を使用すると:

- Docker の内部 DNS が機能しなくなる
- サービス名による名前解決ができなくなる
- コンテナ間の隔離が失われる
Inception 課題では Docker network による隔離とサービス名解決が必須のため、`network_mode: host` は禁止されています。
---
### 10. セキュリティ関連（レビュー頻出）
**Q: NGINX で TLS を有効化するために必要な最低限の設定は？**

A:
```nginx
server {
    listen 443 ssl;                              	# 1. ポート443でSSL有効化
    ssl_certificate     /etc/nginx/ssl/server.crt;  # 2. サーバー証明書
    ssl_certificate_key /etc/nginx/ssl/server.key;  # 3. 秘密鍵
}
```
Inception では追加で以下も設定:
- `ssl_protocols TLSv1.2 TLSv1.3;`（セキュリティ強化）

**Q: なぜ秘密鍵を外部に漏らしてはいけないのですか？**

A: 秘密鍵が漏洩すると、攻撃者が:

- サーバーになりすまして通信を傍受できる
- 暗号化された通信を復号できる
- 中間者攻撃（MITM）を実行できる

そのため、秘密鍵は:
- パーミッションを 600（所有者のみ読み書き可能）に設定
- Git にコミットしない（.gitignore に追加）
- Docker secrets で管理する（Inception の要件）
---
## 弱点の自己分析
## 理解が不十分だった項目
1. **openssl コマンドの構文**: `openssl x509 genrsa` は誤り。正しくは `openssl genrsa` または `openssl req -x509`
2. **location の優先順位**: prefix の位置を忘れていた
3. **root と alias の違い**: 概念は理解していたが、具体例が不足

### 新たに学んだこと
1. **`-nodes` オプション:** "no DES" の略で、秘密鍵を暗号化しない。自動起動に必須。
2. **location のマッチング処理:** 正規表現は「上から順に」評価される。設定の順序が重要。
3. **alias の末尾 /:** location が `/` で終わる場合、alias も `/` で終わる必要がある。
4. **Docker 内部 DNS:** `127.0.0.11` が自動的に起動し、サービス名を解決する。
### レビューで特に注意すべきポイント
1. **TLS の基礎知識:** TLS 1.2/1.3 の違い、なぜ古いバージョンを使わないか
2. **FastCGI の仕組み:** CGI との違い、PHP-FPM の役割
3. **リバースプロキシの役割:** TLS終端、プロトコル変換、窓口一元化
4. **Docker network:** サービス名解決の仕組み、`network_mode: host` が禁止される理由
5. **NGINX 設定の詳細:** location の優先順位、try_files の動作、root と alias の違い