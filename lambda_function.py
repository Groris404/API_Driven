# --- CONFIGURATION ---
# On force les credentials pour que AWS CLI ne râle pas
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
# L'URL externe est récupérée de votre environnement ou définie ici si besoin
ENDPOINT := $(if $(AWS_END),$(AWS_END),http://localhost:4566)

# --- COMMANDES ---
.PHONY: help deploy test clean check-env

help: ## Affiche cette aide
	@echo "📚 COMMANDES DISPONIBLES :"
	@echo "  make deploy   : Package la Lambda et déploie l'API Gateway"
	@echo "  make test     : Teste l'API via curl (Status)"
	@echo "  make stop     : Envoie l'ordre d'arrêt à l'instance"
	@echo "  make start    : Envoie l'ordre de démarrage à l'instance"

check-env:
	@if [ -z "$(AWS_END)" ]; then \
		echo "⚠️  ATTENTION : La variable AWS_END n'est pas définie."; \
		echo "👉 Faites : export AWS_END=https://votre-url-codespace..."; \
		exit 1; \
	fi

deploy: check-env ## Lance le script de déploiement
	@echo "🚀 Démarrage du déploiement..."
	@chmod +x deploy.sh
	@./deploy.sh

test: check-env ## Vérifie le status de l'instance via l'API
	@echo "🧪 Test de l'API (Status)..."
	@# On récupère l'ID de l'API dynamiquement
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(ENDPOINT) --query 'items[0].id' --output text); \
	if [ -z "$$API_ID" ] || [ "$$API_ID" = "None" ]; then \
		echo "❌ Aucune API trouvée via $(ENDPOINT)"; \
		exit 1; \
	fi; \
	echo "   -> Cible API : $$API_ID"; \
	echo "   -> Résultat :"; \
	curl -s "http://localhost:4566/restapis/$$API_ID/prod/_user_request_/manage?action=status" | jq . || curl -s "http://localhost:4566/restapis/$$API_ID/prod/_user_request_/manage?action=status"
	@echo ""

start: check-env ## Démarre l'EC2 via l'API
	@echo "🟢 Demande de démarrage..."
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(ENDPOINT) --query 'items[0].id' --output text); \
	curl -s "http://localhost:4566/restapis/$$API_ID/prod/_user_request_/manage?action=start"

stop: check-env ## Arrête l'EC2 via l'API
	@echo "🔴 Demande d'arrêt..."
	@API_ID=$$(aws apigateway get-rest-apis --endpoint-url=$(ENDPOINT) --query 'items[0].id' --output text); \
	curl -s "http://localhost:4566/restapis/$$API_ID/prod/_user_request_/manage?action=stop"
