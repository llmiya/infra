.PHONY: up down check logs ps restart up-secure check-secure keychain-init keychain-export backup restore alert-test up-dingding-stream bridge-up bridge-down bridge-status

COMPOSE = docker compose -f docker-compose.yml

BACKUP_FILE ?=

up-secure:
	bash -c 'eval "$$(bash scripts/secrets_keychain.sh export-env)" && bash scripts/dingding_bridge_ctl.sh start && $(COMPOSE) up -d'

check-secure:
	bash -c 'eval "$$(bash scripts/secrets_keychain.sh export-env)" && bash scripts/infra_smoke_check.sh'

up-dingding-stream:
	bash -c 'eval "$$(bash scripts/secrets_keychain.sh export-env)" && export DINGTALK_MODE=stream && bash scripts/dingding_bridge_ctl.sh restart && $(COMPOSE) up -d'

keychain-init:
	bash scripts/secrets_keychain.sh init

keychain-export:
	bash scripts/secrets_keychain.sh export-env

up:
	bash scripts/dingding_bridge_ctl.sh start
	$(COMPOSE) up -d

down:
	$(COMPOSE) down
	bash scripts/dingding_bridge_ctl.sh stop

check:
	bash scripts/infra_smoke_check.sh

logs:
	$(COMPOSE) logs --tail=200

ps:
	$(COMPOSE) ps

restart:
	bash scripts/dingding_bridge_ctl.sh restart
	$(COMPOSE) restart

backup:
	bash scripts/pg_backup.sh

restore:
	bash scripts/pg_restore.sh "$(BACKUP_FILE)"

alert-test:
	bash scripts/trigger_test_alert.sh

bridge-up:
	bash scripts/dingding_bridge_ctl.sh start

bridge-down:
	bash scripts/dingding_bridge_ctl.sh stop

bridge-status:
	bash scripts/dingding_bridge_ctl.sh status
