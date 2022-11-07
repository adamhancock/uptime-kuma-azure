## az group create -n "uptimekuma" -l "westeurope"
az deployment group create -n uptimekuma \
  -g "uptimekuma" \
  --template-file ./main.bicep
