# Create/refresh application Secret from variables using the file in pipelines/templates
- bash: |
    set -euo pipefail
    TEMPLATE="$(Build.SourcesDirectory)/pipelines/templates/app-secret.yaml.tmpl"

    # Export the variables the template expects
    export APP_SECRET_NAME="${{ parameters.appSecretName }}"
    export NAMESPACE="${{ parameters.namespace }}"

    # Render and apply without echoing secrets
    envsubst < "$TEMPLATE" | kubectl apply -f -
  displayName: 'Apply app Secret from pipelines/templates/app-secret.yaml.tmpl'
  env:
    # Map your ADO secret variables here (create them in the pipeline or a Variable Group)
    SYS_PASSPHRASE: $(SYS_PASSPHRASE)
    ADMIN_PASSWORD: $(ADMIN_PASSWORD)
    KEYSTORE_PASSPHRASE: $(KEYSTORE_PASSPHRASE)
    TRUSTSTORE_PASSPHRASE: $(TRUSTSTORE_PASSPHRASE)

# Helm deploy — pass the Secret name so your chart can reference it
- bash: |
    set -euo pipefail
    CHART="$(Build.SourcesDirectory)/${{ parameters.chartPath }}"
    VALUES="$(Build.SourcesDirectory)/${{ parameters.valuesFile }}"
    test -f "$CHART/Chart.yaml" && test -f "$VALUES"
    helm version || (curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash)

    helm upgrade --install "${{ parameters.releaseName }}" "$CHART" \
      -n "${{ parameters.namespace }}" -f "$VALUES" \
      --set image.tag="${{ parameters.imageTag }}" \
      --set imagePullSecrets[0].name="${{ parameters.jfrogPullSecretName }}" \
      --set secret.secretname="${{ parameters.appSecretName }}" \
      --wait --atomic --history-max 10 --timeout 5m
  displayName: 'Helm upgrade/install'
