#!/bin/bash

# --- CORRECTION 401 : ON FORCE LES CREDENTIALS ICI ---
# C'est indispensable pour que le client AWS accepte de signer les requêtes
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER="" 
# (AWS_PAGER="" empêche le CLI de bloquer en attendant que vous appuyiez sur 'q')

# Configuration de la cible (Localhost par sécurité pour le déploiement)
# Si la variable n'est pas définie par le Makefile, on force localhost
if [ -z "$AWS_END" ]; then
    export AWS_END="http://localhost:4566"
fi

echo "🔧 Déploiement vers : $AWS_END"

FNAME="ManageEC2"
API_NAME="EC2Controller"
ROLE="arn:aws:iam::000000000000:role/lambda-role"

# 1. Packaging
echo "📦 Packaging..."

# Sécurité : installation de zip si absent
if ! command -v zip &> /dev/null; then
    sudo apt-get update -qq || true
    sudo apt-get install -y zip -qq
fi

# Sécurité : renommage si mauvais nom de fichier
if [ -f "lambda_func.py" ]; then mv lambda_func.py lambda_function.py; fi

rm -f function.zip
zip function.zip lambda_function.py > /dev/null

if [ ! -f "function.zip" ]; then
   echo "❌ Erreur: Le ZIP a échoué."
   exit 1
fi

# 2. Lambda
echo "🚀 Mise à jour Lambda..."
# Suppression silencieuse de l'ancienne version
aws lambda delete-function --function-name $FNAME --endpoint-url=$AWS_END > /dev/null 2>&1

aws lambda create-function \
    --function-name $FNAME \
    --zip-file fileb://function.zip \
    --handler lambda_function.lambda_handler \
    --runtime python3.9 \
    --role $ROLE \
    --endpoint-url=$AWS_END \
    --timeout 10 > /dev/null

echo "   -> Lambda OK."

# 3. API Gateway
echo "🌐 Création API..."
API_ID=$(aws apigateway create-rest-api --name "$API_NAME" --endpoint-url=$AWS_END --query 'id' --output text)

# VERIFICATION CRITIQUE
if [ -z "$API_ID" ]; then
    echo "❌ ERREUR : Impossible de créer l'API. Vérifiez que LocalStack tourne."
    exit 1
fi

PARENT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --endpoint-url=$AWS_END --query 'items[0].id' --output text)
RES_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $PARENT_ID --path-part manage --endpoint-url=$AWS_END --query 'id' --output text)

aws apigateway put-method --rest-api-id $API_ID --resource-id $RES_ID --http-method GET --authorization-type NONE --endpoint-url=$AWS_END > /dev/null

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RES_ID \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:$FNAME/invocations \
    --endpoint-url=$AWS_END > /dev/null

aws apigateway create-deployment --rest-api-id $API_ID --stage-name prod --endpoint-url=$AWS_END > /dev/null

echo "✅ Déploiement terminé (API ID: $API_ID)"
