#!/bin/sh

# MANUAL STEPS
#wget -O - https://raw.githubusercontent.com/uclixngithubclassroom/classroom/UCLAzureDeploy/deploy_classroom.sh | bash
#bash <(curl -s https://raw.githubusercontent.com/uclixngithubclassroom/classroom/UCLAzureDeploy/deploy_classroom.sh)
#wget https://raw.githubusercontent.com/uclixngithubclassroom/classroom/UCLAzureDeploy/deploy_classroom.sh | bash deploy_classroom.sh


#Navigate to the repo automatically
echo "Cloning the repo --->"
git clone https://github.com/uclixngithubclassroom/classroom.git
cd classroom
git checkout UCLAzureDeploy

valid=false
regex=^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$

#LOCATIONS = centralus,eastasia,southeastasia,eastus,eastus2,westus,westus2,northcentralus,southcentralus,westcentralus,northeurope,westeurope,japaneast,japanwest,brazilsouth,australiasoutheast,australiaeast,westindia,southindia,centralindia,canadacentral,canadaeast,uksouth,ukwest,koreacentral,koreasouth,francecentral,southafricanorth,uaenorth,australiacentral
# Read details for the resource group and its elements from the user

while :
do
	read -p 'Enter the Resource Group Name that Classroom will be deployed (Case sensitive): ' RESOURCE_GROUP_NAME
	if [[ $RESOURCE_GROUP_NAME =~ ^[A-Za-z0-9._-()]*[^.]$ ]];
	then
		echo "Valid resource group name!"
		break
	else
		echo "Resource group names only allow alphanumeric characters, periods, underscores, hyphens and parenthesis and cannot end in a period."
	fi
done

echo "The list of Azure Regions: --->"
az account list-locations -o table

read -p 'Enter the resource location for the deployment [ukwest, uksouth]:' RESOURCE_GROUP_LOCATION

read -p 'Enter the AKS Cluster Name that Classroom will be deployed (Case sensitive): ' AKS_CLUSTER_NAME
read -p 'Enter the Airbrake Project ID  (Case sensitive): ' AIRBRAKE_PROJECT_ID
read -p 'Enter the Airbrake Project Key  (Case sensitive): ' AIRBRAKE_PROJECT_KEY
read -p 'Enter the Azure Container Registery name: ' ACR_NAME
read -p 'Enter the Github Client ID: ' GITHUB_CLIENT_ID
read -p 'Enter the Github Client Secret: ' GITHUB_CLIENT_SECRET
read -p 'Enter the non-staff Github Admin ID: ' NON_STAFF_GITHUB_ADMIN_IDS

# Variable formatting
#AIRBRAKE_PROJECT_ID="'${AIRBRAKE_PROJECT_ID}'"
#AIRBRAKE_PROJECT_KEY="'${AIRBRAKE_PROJECT_KEY}'"
#GITHUB_CLIENT_ID="'${GITHUB_CLIENT_ID}'"
#GITHUB_CLIENT_SECRET="'${GITHUB_CLIENT_SECRET}'"
#NON_STAFF_GITHUB_ADMIN_IDS="'${NON_STAFF_GITHUB_ADMIN_IDS}'"


# Environment configuration for creating rake secret
#gem install bundler -v 2.0.2
#gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
#\curl -sSL https://get.rvm.io | bash -s stable
# Update to ruby version specified in .ruby-version file
#[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
#rvm install (ruby-version)
#SECRET_KEY_BASE=$()

#create resource-group
echo "Creating Resource Group -->"
az group create --name $RESOURCE_GROUP_NAME --location $RESOURCE_GROUP_LOCATION

# Create an Azure Container Registry inside the resource group  
echo "Creating Azure Container Registry in the Resource Group -->"
az acr create --resource-group $RESOURCE_GROUP_NAME --name $ACR_NAME --sku Basic

# Login to ACR
echo "Login in to ACR -->"
az acr login --name $ACR_NAME

# Create Service Principle
SERVICE_PRINCIPLE=$(az ad sp create-for-rbac --skip-assignment)

echo "SERVICE_PRINCIPLE -> $SERVICE_PRINCIPLE"/

# Parse JSON and get appId
APP_ID=$(jq -r '.appId' <<< "$SERVICE_PRINCIPLE") 
APP_PW=$(jq -r '.password' <<< "$SERVICE_PRINCIPLE") 

echo "App Id -> $APP_ID"
echo "App password -> $APP_PW"

# Build docker image on acr
az acr build --file Dockerfile --registry $ACR_NAME --image classroom_rubyrails .

# Get the ACR registry resource id
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP_NAME --query "id" --output tsv)

echo "ACR ID -> $ACR_ID"

# Create an Azure Kubernetes Service inside the Resource Group
echo "Creating AKS Cluster in the Resource Group -->"
az aks create --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --node-count 3 --service-principal $APP_ID  --client-secret $APP_PW --generate-ssh-keys

# Get client id
CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv)
echo "Client ID -> $CLIENT_ID"

# Create role assignment
az role assignment create --assignee $APP_ID --role acrpull --scope $ACR_ID

# Connect to cluster
echo "Connecting to AKS Cluster -->"
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME

# Navigate to configuration folder
cd azure_deployment

#Configure variables
sed -i "s|\$AIRBRAKE_PROJECT_ID|'${AIRBRAKE_PROJECT_ID}'|" rubyrails-deployment.yaml
sed -i "s|\$AIRBRAKE_PROJECT_KEY|'${AIRBRAKE_PROJECT_KEY}'|" rubyrails-deployment.yaml
sed -i "s|\$CLASSROOMACR|${ACR_NAME}|" rubyrails-deployment.yaml
sed -i "s|\$GITHUB_CLIENT_ID|${GITHUB_CLIENT_ID}|" rubyrails-deployment.yaml
sed -i "s|\$GITHUB_CLIENT_SECRET|${GITHUB_CLIENT_SECRET}|" rubyrails-deployment.yaml
sed -i "s|\$NON_STAFF_GITHUB_ADMIN_IDS|${NON_STAFF_GITHUB_ADMIN_IDS}|" rubyrails-deployment.yaml

# Deploy it on AKS
kubectl create -f classroom-classroom-data-elasticsearch-data-persistentvolumeclaim.yaml,classroom-classroom-data-elasticsearch-logs-persistentvolumeclaim.yaml,classroom-classroom-data-postgres-data-persistentvolumeclaim.yaml,classroom-classroom-data-postgres-logs-persistentvolumeclaim.yaml,classroom-classroom-data-redis-data-persistentvolumeclaim.yaml,classroom-classroom-data-redis-logs-persistentvolumeclaim.yaml,elasticsearch-deployment.yaml,elasticsearch-service.yaml,memcached-deployment.yaml,memcached-service.yaml,postgresql-deployment.yaml,postgresql-service.yaml,redis-deployment.yaml,redis-service.yaml,rubyrails-deployment.yaml,rubyrails-service.yaml

# Show pod status
kubectl get pod -w

# Clear the Azure CLI
rm -rf classroom