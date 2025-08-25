azure-pipeline-1.yaml
trigger:
  branches: [ main ]

stages:
- stage: Deploy
  jobs:
  - template: pipelines/templates/jfrog-helm-deploy.yml
    parameters:
      azureSubscription: 'myakssc'
      aksResourceGroup: 'rg-lab-aks-0001'
      aksName: 'aks-lab-aks-0001'
      agentPoolName: 'vm-sha-linux-lab-0001'

      namespace: 'javaapp-1'
      releaseName: 'javaapp1'
      chartPath: 'charts/java-app'
      valuesFile: 'charts/java-app/values-javaapp-1-jfrog.yaml'
      imageTag: '1.0'

      jfrogServer: 'myjfrog.company.com'     # registry host (no https)
      jfrogPullSecretName: 'jfrog-pull'
