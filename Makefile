# --- CONFIGURATION ---
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
ENDPOINT := $(if $(AWS_END),$(AWS_END),http://localhost:4566)

.PHONY: help all install infra deploy test urls clean

help: ## Affiche l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

check-env:
	@if [ -z "$(AWS_END)" ]; then \
		echo "⚠️  ATTENTION : Variable AWS_END manquante."; \
		echo "👉 Faites : export AWS_END=https://votre-url-codespace..."; \
		exit 1; \
	fi

all: install infra deploy urls ## 🌟 FAIT TOUT (Install -> EC2 -> API -> URLs)

install: ## Installe les dépendances (zip, awscli)
	@echo "📦 Installation des outils..."
	@sudo apt-get update -qq && sudo apt-get install -y zip -qq
	@pip install awscli -q
	@echo "✅ Outils installés."

infra: check-env ## Crée l'Instance EC2 (si elle n'existe pas)
	@echo "🏗️  Vérification de l'infrastructure..."
	@if aws ec2 describe-instances --filters "Name=tag:Name,Values=MyWorker" --endpoint-url=$(ENDPOINT) --query "Reservations" --output text | grep -q "RESERVATIONS"; then \
		echo "✅ L'instance 'MyWorker' existe déjà."; \
	else \
		echo "🚀 Création de l'instance EC2 'MyWorker'..."; \
		aws ec2 create-key-pair --key-name atelier-key --endpoint-url=$(ENDPOINT) > /dev/null 2>&1 || true; \
		aws ec2 run-instances \
			--image-id ami-df7100bc \
			--count 1 \
			--instance-type t2.micro \
			--key-name atelier-key \
			--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MyWorker}]' \
			--endpoint-url=$(ENDPOINT) > /dev/null; \
		echo "✅ Instance créée !"; \
	fi

deploy: check-env ## Lance le script de déploiement API
	@chmod +x deploy.sh
	@./deploy.sh

test: check-env ## Teste l'API via curl
	@echo "🧪 Test Status..."
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(ENDPOINT) --query 'items[0].id' --output text); \
	curl -s "http://localhost:4566/restapis/$$API_ID/prod/_user_request_/manage?action=status"

urls: check-env ## Affiche les liens finaux
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(ENDPOINT) --query 'items[0].id' --output text); \
	BASE=$$(echo $(ENDPOINT) | sed 's/https:\/\///'); \
	echo ""; \
	echo "🔗 VOS LIENS FINAUX :"; \
	echo "------------------------------------------------"; \
	echo "🔍 STATUS : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=status"; \
	echo "🟢 START  : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=start"; \
	echo "🔴 STOP   : https://$${BASE}/restapis/$${API_ID}/prod/_user_request_/manage?action=stop"; \
	echo "------------------------------------------------";
