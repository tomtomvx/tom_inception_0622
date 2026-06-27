# USER_DOC - User Operation Guide

This document explains how an end user or administrator can operate the
Inception stack. It can also be used directly as a quick review cheat sheet.

## Service Overview

This project starts a WordPress site with Docker Compose. It is composed of
three containers.

| Service | Role | Access |
| --- | --- | --- |
| `nginx` | Public HTTPS entry point and web server that handles TLS termination | host port `443` |
| `wordpress` | Web application running through PHP-FPM | internal port `9000` |
| `mariadb` | Database server used by WordPress | internal port `3306` |

Request flow:

```text
Browser
  -> HTTPS :443
  -> NGINX
  -> FastCGI wordpress:9000
  -> WordPress / PHP-FPM
  -> SQL mariadb:3306
  -> MariaDB
```

Only NGINX is exposed externally. WordPress and MariaDB communicate only inside
the Docker bridge network.

## Start and Stop

Run commands from the repository root.

```sh
cd <your_repozitory>
```

Before the first start, create the host-side persistent data directories.

```sh
mkdir -p /home/tvaroux/data/mariadb
mkdir -p /home/tvaroux/data/wordpress
```

Build and start:

```sh
make up
```

`make up` builds the images and starts the containers in the background.

Stop while keeping data:

```sh
make down
```

Restart:

```sh
make re
```

Start with existing images without building:

```sh
make up-no-build
```

Remove containers and Compose volumes:

```sh
make down-v
```

Note: `make down-v` removes Docker volume objects. However, this project's real
data is stored in `/home/tvaroux/data/mariadb` and
`/home/tvaroux/data/wordpress`. Remove those host directories only when you
want a complete reset.

## Access the Website and Admin Panel

Normal URLs:

```text
https://tvaroux.42.fr
https://127.0.0.1
```

If `tvaroux.42.fr` does not resolve, add it to `/etc/hosts` on the VM or
evaluation host.

```text
127.0.0.1 tvaroux.42.fr
```

The certificate is self-signed, so a browser warning may appear. This is
expected for this project.

WordPress admin panel:

```text
https://tvaroux.42.fr/wp-admin
https://127.0.0.1/wp-admin
```

The admin username is stored in `srcs/.env`.

```env
WP_ADMIN_USER=ado
```

The editor username is also stored in `srcs/.env`.

```env
WP_USER=wpeditor
```

The subject forbids using an admin username that contains `admin` or `Admin`.

Check command:

```sh
grep -i admin srcs/.env
```

This project uses a custom username.

## Locate and Manage Credentials

Non-secret configuration is stored in `srcs/.env`.

```text
srcs/.env
```

Create it from the sample file.

```sh
cp srcs/.env_sample srcs/.env
```

Sample values:

```env
DOMAIN_NAME=tvaroux.42.fr

MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser
MARIADB_PORT=3306

WP_ADMIN_USER=ado
WP_ADMIN_EMAIL=ado@example.com
WP_USER=wpeditor
WP_USER_EMAIL=editor@example.com
```

Passwords are stored as Docker secret files under `secrets/`.

```text
secrets/
```

Create them before startup.

```sh
mkdir -p secrets
echo -n pw > secrets/db_password.txt
echo -n pw > secrets/wp_admin_password.txt
echo -n pw > secrets/wp_editor_password.txt
```

Secret mapping:

| Secret file | Purpose | Container path |
| --- | --- | --- |
| `secrets/db_password.txt` | MariaDB WordPress user password | `/run/secrets/db_password` |
| `secrets/wp_admin_password.txt` | WordPress admin password | `/run/secrets/wp_admin_password` |
| `secrets/wp_editor_password.txt` | WordPress editor password | `/run/secrets/wp_editor_password` |

Do not commit `srcs/.env` or the contents of `secrets/`.

After WordPress has been installed once, changing a secret file does not
automatically update existing user passwords or `wp-config.php`. For a clean
reset, remove the persistent data and start again.

## Check That Services Are Running Correctly

Container status:

```sh
docker compose -f srcs/docker-compose.yml ps
```

Makefile shortcuts:

```sh
make inspect-nginx
make inspect-wordpress
make inspect-mariadb
```

HTTPS check:

```sh
make curl-https
```

This checks TLS connectivity without opening a browser.

Direct TLS checks:

```sh
openssl s_client -connect 127.0.0.1:443 -tls1_1 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null
```

Explanation:

- HTTPS is handled by NGINX.
- The only host-published port in Compose is `443`.
- The TLS versions allowed by NGINX are `TLSv1.2` and `TLSv1.3`.
- The certificate is self-signed.

