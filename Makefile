# レビュー開始前にレビュアーがターミナルで手実行（Makefileから実行しない）
# docker stop $(docker ps -qa); docker rm $(docker ps -qa)
#; docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q)
#; docker network rm $(docker network ls -q) 2>/dev/null



stop: docker stop $(docker ps -qa)

rm: docker rm $(docker ps -qa)

rmimg: docker rmi -f $(docker images -qa)

rmvol: docker volume rm $(docker volume ls -q)

rmnet: docker network rm $(docker network ls -q) 2>/dev/null



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

re: 

re-start: down up

inspect:




.PHONY: all up build up-no-build down down-v

# .PHONY: all build up up-no-build down down-v re browser curl-https inspect inspect-mariadb inspect-wordpress inspect-nginx inspect-test fclean rebuild
