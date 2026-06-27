# レビュー開始前にレビュアーがターミナルで手実行（Makefileから実行しない）
# docker stop $(docker ps -qa); docker rm $(docker ps -qa)
#; docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q)
#; docker network rm $(docker network ls -q) 2>/dev/null
# docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null

DC = docker compose -f ./srcs/docker-compose.yml

all: up

# detach: 起動後のターミナルを占有しない
# build: ビルド済みのイメージがあれば再ビルドしない
up:
	$(DC) up --detach --build

build:
	$(DC) build

# no-build: ビルド済みのイメージがあれば再ビルドしない
up-no-build:
	$(DC) up --detach --no-build

# down: コンテナを停止して削除する イメージは削除しない
down:
	$(DC) down

# down-v: コンテナを停止して削除し、ボリュームも削除する
down-v:
	$(DC) down --volumes

# curl-https: HTTPSリクエストを送信する
# insecure: 証明書の検証をスキップする
# verbose: 詳細な情報を表示する(TLSハンドシェイクの詳細など)
curl-https:
	curl --insecure --verbose https://127.0.0.1/index.html

re: down up

browser:
	@echo "Try open browser..."
	export DISPLAY=:0 && \
	firefox https://127.0.0.1 || \
	echo "No GUI browser launcher. Use: make curl-https"

inspect:
	@test -n "$(CONTAINER)" || (echo "usage: make inspect CONTAINER=<name>" && exit 1)
	@docker inspect $(CONTAINER) --format 'name={{.Name}} pid={{.State.Pid}} status={{.State.Status}} rallestart={{.RestartCount}}'

inspect-mariadb:
	@$(MAKE) --no-print-directory inspect CONTAINER=mariadb

inspect-wordpress:
	@$(MAKE) --no-print-directory inspect CONTAINER=wordpress

inspect-nginx:
	@$(MAKE) --no-print-directory inspect CONTAINER=nginx

inspect-test:
	@$(MAKE) --no-print-directory inspect CONTAINER=test

fclean: down-v
	sudo rm -rf /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress
	mkdir -p /home/tvaroux/data/mariadb /home/tvaroux/data/wordpress

# fclean のあと、イメージをキャッシュ無しで作り直してバックグラウンド起動（評価前のゼロ再現用）
rebuild: fclean
	$(BUILDKIT_ENV) $(DC) build --no-cache
	$(DC) up -d

stop:
	-docker stop $$(docker ps -qa)

rm:
	-docker rm $$(docker ps -qa)

rmimg:
	-docker rmi -f $$(docker images -qa)

rmvol:
	-docker volume rm $$(docker volume ls -q)

rmnet:
	-docker network rm $$(docker network ls -q) 2>/dev/null

.PHONY: all build up up-no-build down down-v re browser curl-https inspect inspect-mariadb inspect-wordpress inspect-nginx inspect-test fclean rebuild stop rm rmimg rmvol rmnet
