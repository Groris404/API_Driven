# --- CONFIGURATION AUTOMATIQUE ---
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Détection automatique de l'URL Codespaces
# Si on est dans Codespaces, on construit l'URL : https://[NOM_CODESPACE]-4566.[DOMAIN_GITHUB]
# Sinon, on utilise localhost par défaut
CODESPACE_URL := $(shell if [ "$$CODESPACE_NAME" ]; then echo "https://$${CODESPACE_NAME}-4566.$${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"; else echo "http://localhost:4566"; fi)

# On force la variable pour les scripts
export AWS_END=$(CODESPACE_URL)

.PHONY: help all install infra deploy test urls clean check-ready

help: ## Affiche l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

all: install infra deploy urls ## 🌟 COMMANDE MAGIQUE (Tout installer et lancer)

install: ## Installe les outils (zip, awscli)
	@echo "📦 Installation des pré-requis..."
	@(sudo apt-get update -qq || true) && sudo apt-get install -y zip -qq
	@pip install awscli -q
	@echo "✅ Outils installés."

infra: ## Crée l'Instance EC2 'MyWorker'
	@echo "🏗️  Vérification de l'infrastructure sur $(CODESPACE_URL)..."
	@# On check si l'instance existe déjà via son TAG
	@if aws ec2 describe-instances --filters "Name=tag:Name,Values=MyWorker" "Name=instance-state-name,Values=pending,running,stopped" --endpoint-url=$(CODESPACE_URL) --query "Reservations" --output text | grep -q "RESERVATIONS"; then \
		echo "✅ L'instance 'MyWorker' est déjà là."; \
	else \
		echo "🚀 Création de l'instance EC2..."; \
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

deploy: ## Déploie la Lambda et l'API
	@echo "🚀 Déploiement de l'API..."
	@chmod +x deploy.sh
	@./deploy.sh

urls: ## Affiche les liens finaux
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(CODESPACE_URL) --query 'items[0].id' --output text); \
	BASE=$$(echo $(CODESPACE_URL) | sed 's/https:\/\///'); \
	echo ""; \
	echo "🔗 VOS LIENS FINAUX (CTRL+CLICK) :"; \
	echo "------------------------------------------------"; \
	echo "🔍 STATUS : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=status"; \
	echo "🟢 START  : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=start"; \
	echo "🔴 STOP   : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=stop"; \
	echo "------------------------------------------------";

test: ## Teste rapide via curl
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(CODESPACE_URL) --query 'items[0].id' --output text); \
	echo "Test sur API ID: $$API_ID"; \
	curl -s "http://localhost:4566/restapis/$$API_ID/prod/_user_request_/manage?action=status"
