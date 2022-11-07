# Uptime Kuma as a Azure Container App
This is a guide on how to deploy Uptime Kuma as a Azure Container App.
[Source Code Repo](https://github.com/adamhancock/uptime-kuma)
```
az login
az group create -n "uptimekuma" -l "westeurope"
az deployment group create -n uptimekuma \
 -g "uptimekuma" \
 --template-uri https://raw.githubusercontent.com/adamhancock/uptime-kuma-azure/master/dist/main.json
```
