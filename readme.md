# Uptime Kuma as a Azure Container App
This is a guide on how to deploy Uptime Kuma as a Azure Container App.

```
az login
az group create -n "uptimekuma" -l "westeurope"
az deployment group create -n uptimekuma \
 -g "uptimekuma" \
 --template-file 
