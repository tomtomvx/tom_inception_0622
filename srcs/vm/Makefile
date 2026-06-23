# EvalHub General instructions — 評価開始前にレビュアーがターミナルで手実行（Makefileから実行しない）
# docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null
.PHONY: help list-vms list-running start check-vm status stop ip ip-ssh ssh-server  ssh-client eval-check eval-db eval-tls eval-port eval-wp
# --- config ---
VM ?= $(shell VBoxManage list vms | sed -n 's/^"\(.*\)".*/\1/p' | head -n1)
VBOXMANAGE := VBoxManage
SSH_PORT_SERVER   := 3322
SSH_PORT_CLIENT   := 3323
SSH_USER   := tvaroux
SSH_HOST   := localhost
# SSH_PORT はコマンドラインで上書き可能にする
SSH_PORT ?= $(SSH_PORT_SERVER)

# VM名はコマンドライン引数で渡す
# 例: make start VM=tom_inception_vm
VM ?=

.PHONY: list-vms list-running start ssh check-vm

list-vms:
	$(VBOXMANAGE) list vms

list-running:
	$(VBOXMANAGE) list runningvms

check-vm:# 1. コンテナ起動確認
	# docker compose -f ./srcs/docker-compose.yml ps

status: check-vm
	@echo "=== vm state ($(VM)) ==="
	@$(VBOXMANAGE) showvminfo "$(VM)" --machinereadable | grep '^VMState='

start: check-vm
	$(VBOXMANAGE) startvm "$(VM)" --type separate

stop: check-vm
	$(VBOXMANAGE) controlvm "$(VM)" acpipowerbutton

stop-force: check-vm
	$(VBOXMANAGE) controlvm "$(VM)" poweroff

ip: check-vm
	@$(VBOXMANAGE) guestproperty get "$(VM)" "/VirtualBox/GuestInfo/Net/0/V4/IP"

ip-ssh:
	@ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "hostname -I | awk '{print \$$1}'"


ssh:
	ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST)