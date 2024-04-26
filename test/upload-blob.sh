#!/bin/bash

# ./upload-test-blob.sh <EXAMPLE_TENANT_SA_MAIL> <TENANT_ID> <CLIENT_ID> <SUBSCRIPTION_ID> <RESOURCE_GROUP> <STORAGE_ACCOUNT> <CONTAINER_NAME>

EXAMPLE_TENANT_SA_MAIL=$1
TENANT_ID=$2
CLIENT_ID=$3
SUBSCRIPTION_ID=$4
RESOURCE_GROUP=$5
STORAGE_ACCOUNT=$6
CONTAINER_NAME=$7

# get federated token
GCP_TOKEN=`gcloud auth print-identity-token --impersonate-service-account=${EXAMPLE_TENANT_SA_MAIL} --audiences=api://AzureADTokenExchange`
echo ${GCP_TOKEN}

# login with federated credential token: notice the `--allow-no-subscriptions` flag
az login --service-principal \
 -t ${TENANT_ID} \
 -u ${CLIENT_ID} \
 --federated-token ${GCP_TOKEN} \
 --allow-no-subscriptions \
# now, set the subscription to be able to access storage resources: the Azure Entra ID App
# does not have access to the subscription by default
az account set --subscription ${SUBSCRIPTION_ID}

# 5 minutes from now should be more than enough (beware `-d` doesn't work on macOS)
SAS_TOKEN_EXPIRATION=`date -u -d "5 minutes" "+%Y-%m-%dT%H:%M:%SZ"`
SAS_TOKEN=`az storage container generate-sas \
  --account-name ${STORAGE_ACCOUNT} \
  --as-user --auth-mode login \
  --expiry ${SAS_TOKEN_EXPIRATION} \
  --name ${CONTAINER_NAME} \
  --permissions rwl \
  -o tsv`
echo "Getting SAS token: ${SAS_TOKEN}"

TEST_RUN_DATE=`date +"%Y-%m-%dT%H:%M:%SZ"`
FILENAME=test-${TEST_RUN_DATE}.txt
echo "TEST ${TEST_RUN_DATE}" > /tmp/${FILENAME}
echo "Copying test file to container: ${CONTAINER_NAME}"
RESULT=`az storage blob upload \
  --account-name ${STORAGE_ACCOUNT} \
  --container-name ${CONTAINER_NAME} \
  --file /tmp/${FILENAME} \
  --name ${FILENAME} \
  --sas-token ${SAS_TOKEN}`
echo $RESULT
rm /tmp/${FILENAME}
