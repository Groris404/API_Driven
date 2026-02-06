import boto3
import json
import os

def lambda_handler(event, context):
    # --- CONFIGURATION INTELLIGENTE ---
    # La Lambda cherche l'instance qui porte l'étiquette (Tag) "MyWorker"
    TARGET_TAG = "MyWorker"
    
    # Configuration pour parler à LocalStack depuis l'intérieur du conteneur
    ls_hostname = os.environ.get('LOCALSTACK_HOSTNAME', 'localstack')
    endpoint_url = f"http://{ls_hostname}:4566"
    
    ec2 = boto3.client('ec2', endpoint_url=endpoint_url, region_name="us-east-1")

    # 1. RECHERCHE DE L'INSTANCE PAR SON NOM
    try:
        response = ec2.describe_instances(Filters=[
            {'Name': 'tag:Name', 'Values': [TARGET_TAG]},
            {'Name': 'instance-state-name', 'Values': ['pending', 'running', 'stopped']}
        ])
        
        reservations = response.get('Reservations', [])
        if not reservations:
            return {
                "statusCode": 404, 
                "body": json.dumps({"error": f"Instance '{TARGET_TAG}' introuvable. Avez-vous lance 'make infra' ?"})
            }
            
        # On prend la première instance trouvée
        INSTANCE_ID = reservations[0]['Instances'][0]['InstanceId']
        
    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": f"Erreur EC2: {str(e)} "})}

    # 2. PILOTAGE
    params = event.get('queryStringParameters') or {}
    action = params.get('action', 'status')
    
    message = ""
    try:
        if action == 'start':
            ec2.start_instances(InstanceIds=[INSTANCE_ID])
            message = f"Instance {INSTANCE_ID} ({TARGET_TAG}) demarree."
        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[INSTANCE_ID])
            message = f"Instance {INSTANCE_ID} ({TARGET_TAG}) arretee."
        elif action == 'status':
            resp = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
            state = resp['Reservations'][0]['Instances'][0]['State']['Name']
            message = f"Instance {INSTANCE_ID} ({TARGET_TAG}) est: {state}"
        else:
            message = "Action inconnue. Options: ?action=start | stop | status"

        return {
            "statusCode": 200,
            "body": json.dumps({"message": message})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
