#!/bin/bash

# --- CONFIGURATION ---
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Vérification URL
if [ -z "$AWS_END" ]; then
    echo "❌ Erreur: Variable AWS_END manquante."
    exit 1
fi

echo "🔧 Cible : $AWS_END"

FNAME="ManageEC2"
API_NAME="EC2Controller"
ROLE="arn:aws:iam::000000000000:role/lambda-role"

# 1. Packaging (Avec l'outil ZIP standard)
echo "📦 Packaging..."

# Vérification et installation de l'outil zip s'il est absent
if ! command -v zip &> /dev/null; then
    echo "   🛠️ Installation de l'outil 'zip'..."
    sudo apt-get update -qq && sudo apt-get install -y zip -qq
fi

# Gestion du nom de fichier (Sécurité si vous n'avez pas renommé)
if [ -f "lambda_func.py" ] && [ ! -f "lambda_function.py" ]; then
    echo "   ⚠️ Renommage automatique : lambda_func.py -> lambda_function.py"
    mv lambda_func.py lambda_function.py
fi

if [ ! -f "lambda_function.py" ]; then
   echo "❌ Erreur: Fichier 'lambda_function.py' introuvable."
   exit 1
fi

rm -f function.zip
# La commande standard
zip function.zip lambda_function.py > /dev/null

if [ ! -f "function.zip" ]; then
   echo "❌ Erreur: Le ZIP n'a pas été créé."
   exit 1
fi

# 2. Lambda
echo "🚀 Mise à jour Lambda..."
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

# URL
BASE_URL=$(echo $AWS_END | sed 's/https:\/\///')
echo "----------------------------------------------"
echo "✅ SUCCÈS ! TESTEZ VOTRE INFRA ICI :"
echo "https://${API_ID}.execute-api.${BASE_URL}/prod/manage?action=status"
echo "----------------------------------------------"
