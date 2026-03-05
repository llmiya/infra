.PHONY: up down check logs ps restart

COMPOSE = docker compose -f docker-compose.yml

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

check:
	bash scripts/infra_smoke_check.sh

logs:
	$(COMPOSE) logs --tail=200

ps:
	$(COMPOSE) ps

restart:
	$(COMPOSE) restart
