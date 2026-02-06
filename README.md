 **Installation de l'émulateur LocalStack**  
 Les commande suivante sont nécessaire pour le lancement de localstack.
```
sudo -i python3 -m venv ./rep_localstack
```
```
sudo -i pip install --upgrade pip && python3 -m pip install localstack && export S3_SKIP_SIGNATURE_VALIDATION=0
```
```
localstack start -d
```
**vérification des services disponibles**  

**Réccupération de l'API AWS Localstack** 
Votre environnement AWS (LocalStack) est prêt. Pour obtenir votre AWS_ENDPOINT cliquez sur l'onglet **[PORTS]** dans votre Codespace et rendez public votre port **4566** (Visibilité du port).
Réccupérer l'URL de ce port dans votre navigateur qui sera votre ENDPOINT AWS (c'est à dire votre environnement AWS).
Conservez bien cette URL car vous en aurez besoin par la suite.  

Une fois le localstack tout sera automatisés, executer la commande suivante : 

```
make help
```
Vous aurez la totalités des commandes lié au make !

Si la lecture n'est pas votre fort executer seulement : 
```
make all
```
```
make check
```
Pour avoir le status de l'instance ! 

```
make stop 
```
Pour la shutdown ! 
```
make start
```
Pour la relancer ! 

Bien joué ! 
