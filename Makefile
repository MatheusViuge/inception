NAME = inception
COMPOSE = docker-compose
COMPOSE_FILE = srcs/docker-compose.yml

GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
RED = \033[0;31m
CYAN = \033[0;36m
BOLD = \033[1m
BLINK = \033[5m
RESET = \033[0m

all: up

up:
	@echo "$(BOLD)$(BLINK)$(GREEN)🚀 [$(NAME)] Subindo containers...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) up -d --build
	@echo "$(BOLD)$(GREEN)✅ [$(NAME)] Containers iniciados com sucesso.$(RESET)"

down:
	@echo "$(BOLD)$(YELLOW)🛑 [$(NAME)] Derrubando containers...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) down
	@echo "$(YELLOW)✔ [$(NAME)] Containers finalizados.$(RESET)"

start:
	@echo "$(BOLD)$(GREEN)▶ [$(NAME)] Iniciando containers existentes...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) start
	@echo "$(GREEN)✔ [$(NAME)] Containers iniciados.$(RESET)"

stop:
	@echo "$(BOLD)$(YELLOW)⏸ [$(NAME)] Parando containers...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) stop
	@echo "$(YELLOW)✔ [$(NAME)] Containers parados.$(RESET)"

restart: down up

re: restart

build:
	@echo "$(BOLD)$(BLUE)🔧 [$(NAME)] Construindo imagens...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) build
	@echo "$(BLUE)✔ [$(NAME)] Build concluído.$(RESET)"

ps:
	@echo "$(BOLD)$(CYAN)📦 [$(NAME)] Status dos containers:$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) ps

logs:
	@echo "$(BOLD)$(CYAN)📜 [$(NAME)] Exibindo logs...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) logs -f

config:
	@echo "$(BOLD)$(BLUE)🔍 [$(NAME)] Validando docker-compose.yml...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) config
	@echo "$(GREEN)✔ [$(NAME)] Arquivo válido.$(RESET)"

clean:
	@echo "$(BOLD)$(RED)🧹 [$(NAME)] Removendo containers e volumes...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) down -v
	@echo "$(RED)✔ [$(NAME)] Limpeza concluída.$(RESET)"

fclean: clean
	@echo "$(BOLD)$(RED)🔥 [$(NAME)] Limpando imagens Docker...$(RESET)"
	@docker image prune -af
	@echo "$(RED)✔ [$(NAME)] Limpeza pesada concluída.$(RESET)"

status: ps

reset:
	@echo "$(BOLD)$(RED)💣 [$(NAME)] Resetando tudo do zero...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) down -v
	@docker image prune -af
	@sudo rm -rf /home/mviana/data/mariadb/*
	@sudo rm -rf /home/mviana/data/wordpress/*
	@echo "$(BOLD)$(GREEN)🚀 [$(NAME)] Subindo do zero...$(RESET)"
	@$(COMPOSE) -f $(COMPOSE_FILE) up -d --build
	@echo "$(BOLD)$(GREEN)✅ [$(NAME)] Pronto!$(RESET)"

help:
	@echo "$(BOLD)$(CYAN)\n📘 Comandos disponíveis:\n$(RESET)"
	@echo "$(GREEN)  make up$(RESET)       → sobe os containers (build incluso)"
	@echo "$(YELLOW)  make down$(RESET)     → derruba os containers"
	@echo "$(GREEN)  make start$(RESET)    → inicia containers já criados"
	@echo "$(YELLOW)  make stop$(RESET)     → para os containers"
	@echo "$(BLUE)  make build$(RESET)    → builda as imagens"
	@echo "$(CYAN)  make ps$(RESET)       → mostra status dos containers"
	@echo "$(CYAN)  make logs$(RESET)     → mostra logs em tempo real"
	@echo "$(BLUE)  make config$(RESET)   → valida docker-compose.yml"
	@echo "$(RED)  make clean$(RESET)    → remove containers + volumes"
	@echo "$(RED)  make fclean$(RESET)   → remove também imagens"
	@echo "$(BOLD)$(RED)  make reset$(RESET)	→ reinicia do zero o projeto"
	@echo "$(CYAN)  make help$(RESET)     → mostra esta ajuda\n"

.PHONY: all up down start stop restart re build ps logs config clean fclean status help reset
