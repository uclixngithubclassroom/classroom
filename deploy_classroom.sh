#!/bin/sh

# MANUAL STEPS
#echo "Cloning the repo --->"
#git clone https://github.com/uclixngithubclassroom/classroom.git
#cd classroom
#git checkout UCLAzureDeploy
#bash deploy_classroom.sh

#AKS_RESOURCE_GROUP=myAKSResourceGroup
#AKS_CLUSTER_NAME=myAKSCluster
#ACR_NAME=myACRRegistry

#echo "Enter the resource group name that Classroom will be deployed (Case sensitive): "
#read -p 'Enter the resource group name that Classroom will be deployed (Case sensitive): ' ACR_RESOURCE_GROUP

read -p 'Enter the Resource Group Name that Classroom will be deployed (Case sensitive): ' RESOURCE_GROUP_NAME
read -p 'Enter the resource location for the deployment [ukwest, uksouth]:' RESOURCE_GROUP_LOCATION
read -p 'Enter the AKS Cluster Name that Classroom will be deployed (Case sensitive): ' AKS_CLUSTER_NAME
read -p 'Enter the ACR Name that Classroom will be deployed (Case sensitive): ' ACR_NAME

#create resource-group
echo "Creating Resource Group -->"
az group create --name $RESOURCE_GROUP_NAME --location $RESOURCE_GROUP_LOCATION

# Create an Azure Container Registry inside the resource group  
echo "Creating Azure Container Registry in the Resource Group -->"
az acr create --resource-group $RESOURCE_GROUP_NAME --name $ACR_NAME --sku Basic

# Login to ACR
echo "Login in to ACR -->"
az acr login --name $ACR_NAME

# Build docker image on acr
az acr build --file Dockerfile --registry $ACR_NAME --image classroom_rubyrails .

# Create Service Principle
SERVICE_PRINCIPLE=$(az ad sp create-for-rbac --skip-assignment)

echo "SERVICE_PRINCIPLE -> $SERVICE_PRINCIPLE"


#get client id
CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv)

echo "Client ID -> $CLIENT_ID"

# Get the ACR registry resource id
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP_NAME --query "id" --output tsv)

echo "ACR ID -> $ACR_ID"

# Create role assignment
az role assignment create --assignee $CLIENT_ID --role acrpull --scope $ACR_ID -g


# Create AKS Cluster



# Connect to cluster
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS

# Deploy it on AKS
kubectl create -f classroom-classroom-data-elasticsearch-data-persistentvolumeclaim.yaml,classroom-classroom-data-elasticsearch-logs-persistentvolumeclaim.yaml,classroom-classroom-data-postgres-data-persistentvolumeclaim.yaml,classroom-classroom-data-postgres-logs-persistentvolumeclaim.yaml,classroom-classroom-data-redis-data-persistentvolumeclaim.yaml,classroom-classroom-data-redis-logs-persistentvolumeclaim.yaml,elasticsearch-deployment.yaml,elasticsearch-service.yaml,memcached-deployment.yaml,memcached-service.yaml,postgresql-deployment.yaml,postgresql-service.yaml,redis-deployment.yaml,redis-service.yaml,rubyrails-deployment.yaml,rubyrails-service.yaml

# Clean up the Azure Shell
rm -rf classroom

#
