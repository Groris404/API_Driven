# --- CONFIGURATION ---
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

# CALCUL DE L'URL PUBLIQUE UNIQUE
# (Plus de localhost ici)
CODESPACE_URL := $(shell if [ "$$CODESPACE_NAME" ]; then echo "https://$${CODESPACE_NAME}-4566.$${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"; else echo "http://0.0.0.0:4566"; fi)

# On force cette URL pour tout le monde
export AWS_END=$(CODESPACE_URL)

.PHONY: help all install infra deploy urls check start stop

help: ## Affiche l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

all: install infra deploy urls ## 🌟 TOUT FAIRE

install: ## Installe les outils
	@echo "📦 Installation..."
	@(sudo apt-get update -qq || true) && sudo apt-get install -y zip -qq
	@pip install awscli -q

infra: ## Crée l'EC2 (Via URL Publique)
	@echo "🏗️  Vérification Infrastructure sur $(CODESPACE_URL)..."
	@if aws ec2 describe-instances --filters "Name=tag:Name,Values=MyWorker" "Name=instance-state-name,Values=pending,running,stopped" --endpoint-url=$(CODESPACE_URL) --query "Reservations" --output text | grep -q "RESERVATIONS"; then \
		echo "✅ Instance 'MyWorker' présente."; \
	else \
		echo "🚀 Création Instance..."; \
		aws ec2 create-key-pair --key-name atelier-key --endpoint-url=$(CODESPACE_URL) > /dev/null 2>&1 || true; \
		aws ec2 run-instances \
			--image-id ami-df7100bc \
			--count 1 \
			--instance-type t2.micro \
			--key-name atelier-key \
			--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MyWorker}]' \
			--endpoint-url=$(CODESPACE_URL) > /dev/null; \
		echo "✅ Instance créée !"; \
	fi

deploy: ## Déploie (Via URL Publique)
	@echo "🚀 Déploiement API..."
	@chmod +x deploy.sh && ./deploy.sh

# --- COMMANDES DE PILOTAGE ---

check: ## Check Status
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(CODESPACE_URL) --query 'items[0].id' --output text); \
	printf "🔍 STATUS : "; \
	curl -s "$(CODESPACE_URL)/restapis/$$API_ID/prod/_user_request_/manage?action=status"; \
	echo ""

start: ## Start Instance
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(CODESPACE_URL) --query 'items[0].id' --output text); \
	printf "🟢 START  : "; \
	curl -s "$(CODESPACE_URL)/restapis/$$API_ID/prod/_user_request_/manage?action=start"; \
	echo ""

stop: ## Stop Instance
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(CODESPACE_URL) --query 'items[0].id' --output text); \
	printf "🔴 STOP   : "; \
	curl -s "$(CODESPACE_URL)/restapis/$$API_ID/prod/_user_request_/manage?action=stop"; \
	echo ""

urls: ## Affiche les liens
	@echo ""
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(CODESPACE_URL) --query 'items[0].id' --output text); \
	BASE=$$(echo $(CODESPACE_URL) | sed 's/https:\/\///'); \
	echo "🔗 LIENS :"; \
	echo "------------------------------------------------"; \
	echo "🔍 STATUS : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=status"; \
	echo "🟢 START  : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=start"; \
	echo "🔴 STOP   : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=stop"; \
	echo "------------------------------------------------";
