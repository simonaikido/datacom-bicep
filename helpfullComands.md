# HelpFul Comands

## AZ CLI

### Delete Containers

``` ps1
  az cosmosdb sql container delete --resource-group "rg-secreports-test" --account-name "secreports-nosql-test-lkwq5g24y5h4m" --database-name "secReportsDB-test" --name "cvesContainer"  --yes

  az cosmosdb sql container delete --resource-group "rg-secreports-test" --account-name "secreports-nosql-test-lkwq5g24y5h4m" --database-name "secReportsDB-test" --name "timeDataContainer"  --yes

  az cosmosdb gremlin graph delete --resource-group "rg-secreports-test" --account-name "secreports-gremlin-test-lkwq5g24y5h4m" --database-name "secReportsGDB-poc" --name "graphContainer"  --yes;

  az cosmosdb gremlin graph delete --resource-group "rg-secreports-poc" --account-name "secreports-gremlin-poc-lkwq5g24y5h4m" --database-name "secReportsGDB-poc" --name "graphContainer"  --yes
```
