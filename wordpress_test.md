
docker build -t inception-wp:test .


docker run -d --name wordpress-test-run \
  --network inception-test-net \
  --env-file ../.env \
  -e MARIADB_HOST=mariadb \
  -e DOMAIN_NAME=localhost \
  -e WP_ADMIN_USER=admin \
  -e WP_ADMIN_EMAIL=admin@example.com \
  -e WP_USER=editor \
  -e WP_USER_EMAIL=editor@example.com \
  -e WP_CLI_ALLOW_ROOT=1 \
  --mount type=bind,src="$(pwd)/../../secrets/db_password",dst=/run/secrets/db_password,readonly \
  --mount type=bind,src="$(pwd)/../../secrets/wp_admin_password",dst=/run/secrets/wp_admin_password,readonly \ 
  --mount type=bind,src="$(pwd)/../../secrets/wp_editor_password",dst=/run/secrets/wp_editor_password,readonly \
  inception-wp:test


docker logs wordpress-test-run


docker exec wordpress-test-run wp --allow-root --path=/var/www/html db check
```
allow-root --path=/var/www/html db check
wordpress.wp_commentmeta                           OK
wordpress.wp_comments                              OK
wordpress.wp_links                                 OK
wordpress.wp_options                               OK
wordpress.wp_postmeta                              OK
wordpress.wp_posts                                 OK
wordpress.wp_term_relationships                    OK
wordpress.wp_term_taxonomy                         OK
wordpress.wp_termmeta                              OK
wordpress.wp_terms                                 OK
wordpress.wp_usermeta                              OK
wordpress.wp_users                                 OK
Success: Database checked.
```
