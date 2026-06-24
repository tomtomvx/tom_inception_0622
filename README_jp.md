*このプロジェクトは、42カリキュラムの一環として tvaroux によって作成されました。*

## 概要

Inception は、Docker を使って小さなコンテナ化された Web インフラを構築し、その仕組みを理解することに重点を置いた 42 のプロジェクトです。

このプロジェクトの目的は、複数の独立した Docker コンテナを使って、完全な WordPress サイトを動かすことです。各サービスはそれぞれ専用の Dockerfile からビルドされ、Docker Compose によってまとめて管理されます。

このインフラには以下が含まれます。

- HTTPS の入口となる NGINX
- PHP-FPM で動作する WordPress
- データベースサーバーとしての MariaDB
- 永続データ用の Docker ボリューム
- 機密パスワード用の Docker secrets
- 内部サービス通信専用の Docker ブリッジネットワーク

リクエストの流れは以下の通りです。


```
┌─────────────────────────────────────────────────────────────┐
│                        VM (Ubuntu 22.04)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Docker Compose                      │  │
│  │  ┌─────────┐    ┌─────────────┐    ┌─────────────┐    │  │
│  │  │  NGINX  │◀───│  WordPress  │◀───│   MariaDB   │    │  │
│  │  │ :443    │    │  php-fpm    │    │   :3306     │    │  │
│  │  │ TLS 1.2+│    │  wp-cli     │    │             │    │  │
│  │  └────┬────┘    └──────┬──────┘    └──────┬──────┘    │  │
│  │       │                │                  │           │  │
│  │       └────────────────┴──────────────────┘           │  │
│  │                 tvaroux_network (bridge)              │  │
│  │                                                       │  │
│  │       [volumes: wordpress, mariadb]                   │  │
│  └──────────────── │  ───────────────────────────────────┘  │
│                    │                                        │
│                  Mount                                      │
│                    │                                        │
│          [Docker volumes]                                   │
│  /var/lib/docker/volumes/srcs_wordpress_data/_data          │
│  /var/lib/docker/volumes/srcs_mariadb_data/_data            │
│                    │                                        │
│                Bind (o: bind)                               │
│                    │                                        │
│          [device volumes]                                   │
│            /home/tvaroux/data/wordpress                     │
│            /home/tvaroux/data/mariadb                       │
└─────────────────────────────────────────────────────────────┘
```


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

Docker を使うことで、各サービスをそれぞれ独立したコンテナ内に隔離しつつ、スタック全体を再現可能な形で管理できます。ソースファイルは `srcs/requirements/` 配下にサービスごとに整理されており、各コンポーネントには Dockerfile と関連する設定ファイルがあります。

主なソース構成:

```text
srcs/
  docker-compose.yml
  requirements/
    mariadb/
      Dockerfile
      conf/
      tools/
    nginx/
      Dockerfile
      conf/
    wordpress/
      Dockerfile
      conf/
      tools/
  vm/
secrets/
Makefile
```

## 手順

### 前提条件

プロジェクトを実行する前に、Docker Engine と Docker Compose がインストールされていることを確認してください。

ホスト上に必要なデータディレクトリを作成します。

```bash
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

`srcs/.env` を作成し、機密情報ではない設定値を記述します。例:

```env
YOUR_LEARNER_USERNAME=tvaroux
DOMAIN_NAME=tvaroux.42.fr
MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser
WP_ADMIN_USER=admin
WP_ADMIN_EMAIL=admin@example.com
WP_EDITOR_USER=editor
WP_EDITOR_EMAIL=editor@example.com
```

`secrets/` 配下に secret ファイルを作成します。

```bash
echo -n "db_password_here" > secrets/db_password.txt
echo -n "db_root_password_here" > secrets/db_root_password.txt
echo -n "wp_admin_password_here" > secrets/wp_admin_password.txt
echo -n "wp_editor_password_here" > secrets/wp_editor_password.txt
```

これらのファイルはリポジトリにコミットしてはいけません。

### ビルドと実行

リポジトリのルートからスタックを起動します。

```bash
make up
```

このコマンドは Compose 設定を検証し、サービスイメージをビルドして、コンテナをデタッチモードで起動します。

### アクセス

コンテナが起動したら、サイトには HTTPS 経由でアクセスできます。

```text
https://tvaroux.42.fr
```

ローカル VM やポートフォワード環境では、以下でもテストできます。

```text
https://127.0.0.1
```

WordPress の管理画面は以下からアクセスできます。

```text
https://tvaroux.42.fr/wp-admin
```

### 便利なコマンド

```bash
make build
```

Docker イメージを再ビルドします。

```bash
make up-no-build
```

既存のイメージを、再ビルドせずに起動します。

```bash
make down
```

コンテナを停止して削除します。

```bash
make down-v
```

スタックを停止し、Docker ボリュームも削除します。

```bash
make re
```

スタックを再起動します。

```bash
make curl-https
```

`curl` を使って HTTPS エンドポイントをテストします。

```bash
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

各コンテナの実行状態を確認します。

## プロジェクト説明

### 主な設計方針

このプロジェクトでは、すべてのサービスを 1 台のマシンに直接インストールするのではなく、インフラを 3 つのコンテナに分離しています。

- NGINX だけがホストの `443` ポートに公開されます。
- WordPress は内部 Docker ネットワークを通じて MariaDB と通信します。
- MariaDB のデータと WordPress のファイルは永続ボリュームに保存されます。
- パスワードは通常の環境変数ではなく Docker secrets によって渡されます。
- 各サービスは、スタック内部の仕組みを理解するために、カスタム Dockerfile からビルドされます。

### 仮想マシンと Docker

| 項目 | 仮想マシン | Docker コンテナ |
|---|---|---|
| 仮想化のレベル | ハードウェアを仮想化する | プロセスを仮想化する |
| オペレーティングシステム | 完全なゲスト OS を実行する | ホストのカーネルを共有する |
| 起動時間 | 通常は遅い | 通常は速い |
| リソース使用量 | 重い | 軽い |
| 分離 | 強い OS レベルの分離 | namespace と cgroups によるプロセス分離 |

仮想マシンは、完全に分離された OS が必要な場合に有用です。Docker はより軽量で、個別のサービスをパッケージ化して実行するのに適しています。

このプロジェクトでは、42 の課題要件により、仮想化環境内でプロジェクトを実行する必要があるため、VM の中で Docker を実行しています。

### Secrets と環境変数

| 項目 | Docker secrets | 環境変数 |
|---|---|---|
| 適した用途 | パスワードや機密データ | 機密ではない設定 |
| 露出方法 | `/run/secrets/` 配下にファイルとしてマウントされる | プロセス環境内で見える |
| リスク | 認証情報に対して低め | 認証情報に対して高め |
| 例 | データベースパスワード | ドメイン名、データベース名、ユーザー名 |

このプロジェクトでは、以下のパスワードに Docker secrets を使用しています。

- `db_password`
- `db_root_password`
- `wp_admin_password`
- `wp_editor_password`

環境変数は、ドメイン名、データベース名、ユーザー名など、機密ではない設定にのみ使用しています。

### Docker ネットワークとホストネットワーク

| 項目 | Docker ブリッジネットワーク | ホストネットワーク |
|---|---|---|
| 分離 | コンテナはプライベートネットワークを使う | コンテナがホストネットワークを直接使う |
| サービス検出 | コンテナ同士が名前で解決できる | Docker DNS による分離がない |
| ポート公開 | 選択したポートだけを公開する | サービスがホストポートに直接バインドする可能性がある |
| セキュリティ | より制御しやすい | 分離が弱い |

このプロジェクトでは、専用の Docker ブリッジネットワークを使用しています。コンテナ同士は `wordpress` や `mariadb` のようなサービス名で通信します。

ホストに `443` ポートを公開しているのは NGINX コンテナだけです。MariaDB と WordPress は Docker ネットワークの外部には直接公開されません。

### Docker ボリュームと Bind Mount

| 項目 | Docker ボリューム | Bind mount |
|---|---|---|
| 管理元 | Docker | ホストファイルシステム |
| 移植性 | より移植しやすい | ホスト上のパスに依存する |
| 可視性 | Docker コマンドで管理する | ホスト上で直接見える |
| 用途 | 永続的なアプリケーションデータ | ホストファイルへの直接アクセス |

このプロジェクトでは、bind 形式のドライバーオプションを使った Docker ボリュームを使用しています。これにより、データは以下の場所に永続化されます。

```text
/home/tvaroux/data/mariadb
/home/tvaroux/data/wordpress
```

MariaDB ボリュームにはデータベースファイルが保存され、WordPress ボリュームには WordPress サイトのファイルが保存されます。これにより、コンテナを再ビルドまたは再起動してもデータを保持できます。

## 参考資料

### 公式ドキュメント

- Docker documentation: https://docs.docker.com/
- Docker Compose file reference: https://docs.docker.com/reference/compose-file/
- Docker Compose secrets: https://docs.docker.com/compose/how-tos/use-secrets/
- Docker volumes: https://docs.docker.com/engine/storage/volumes/
- Docker networking: https://docs.docker.com/compose/how-tos/networking/
- NGINX documentation: https://nginx.org/en/docs/
- NGINX SSL module: https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- NGINX FastCGI module: https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- MariaDB documentation: https://mariadb.com/kb/en/documentation/
- MariaDB install database tool: https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db
- WordPress documentation: https://wordpress.org/documentation/
- WP-CLI handbook: https://make.wordpress.org/cli/handbook/
- PHP-FPM documentation: https://www.php.net/manual/en/install.fpm.php
- GNU Make manual: https://www.gnu.org/software/make/manual/make.html
- VirtualBox manual: https://www.virtualbox.org/manual/UserManual.html

### 追加参考資料

- RFC 8446, TLS 1.3: https://datatracker.ietf.org/doc/html/rfc8446
- OpenSSL documentation: https://www.openssl.org/docs/
- Alpine Linux documentation: https://docs.alpinelinux.org/
- Alpine Linux package database: https://pkgs.alpinelinux.org/

### AI の使用について

このプロジェクトでは、学習および開発の補助として AI を使用しました。

AI は以下の目的で使用しました。

- イメージ、コンテナ、ボリューム、ネットワーク、secrets などの Docker の概念説明
- 仮想マシンと Docker コンテナの比較
- Docker Compose の設計方針のレビュー
- shell の entrypoint スクリプト構成の補助
- 検証コマンドの提案
- ドキュメントおよび README 内容の整理

AI は、プロジェクト理解の代替として使用したものではありません。最終的な設計判断、テスト、デバッグ、検証は学生本人が行いました。
