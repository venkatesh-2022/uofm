Option A (recommended): make the Secret a Helm template and feed values from the pipeline
1) Put your Secret in the chart (use stringData, not data)

charts/<your-chart>/templates/secret.yaml

apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.secret.secretname | quote }}
  namespace: {{ .Release.Namespace }}
type: Opaque
stringData:
  ADMIN_PASSWORD: {{ required "secret.adminPassword is required" .Values.secret.adminPassword | quote }}
  KEYSTORE_PASSPHRASE: {{ required "secret.keystorePassphrase is required" .Values.secret.keystorePassphrase | quote }}
  # add more keys as needed...


stringData lets you pass plain text; Kubernetes base64-encodes it server-side. Avoid committing base64 blobs in Git.

2) Values shape (matches what you said you use)

values.yaml

secret:
  secretname: ""            # pipeline sets this
  adminPassword: ""         # pipeline sets this
  keystorePassphrase: ""    # pipeline sets this

3) Pipeline: create nothing, just pass the values to Helm

In your existing job (after you connect to AKS), change the Helm line to:

helm upgrade --install "$(releaseName)" "$CHART" \
  -n "$(namespace)" -f "$VALUES" \
  --set image.tag="$(imageTag)" \
  --set imagePullSecrets[0].name="$(jfrogPullSecretName)" \
  --set secret.secretname="$(appSecretName)" \
  --set secret.adminPassword="$(ADMIN_PASSWORD)" \
  --set secret.keystorePassphrase="$(KEYSTORE_PASSPHRASE)" \
  --wait --atomic --history-max 10 --timeout 5m


…and in that step’s env: map the secret variables (add them in ADO as secret vars or via a variable group):

env:
  ADMIN_PASSWORD: $(ADMIN_PASSWORD)
  KEYSTORE_PASSPHRASE: $(KEYSTORE_PASSPHRASE)


Your chart already reads secret.secretname, so this matches your current values format.

Option B: keep secret.yaml as a plain manifest and apply it before Helm

If you don’t want the Secret inside the chart, you can apply the manifest from the pipeline, filling values at runtime.

1) Turn your file into a template (placeholders)

charts/<your-chart>/manifests/secret.yaml.tmpl

apiVersion: v1
kind: Secret
metadata:
  name: ${APP_SECRET_NAME}
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  ADMIN_PASSWORD: ${ADMIN_PASSWORD}
  KEYSTORE_PASSPHRASE: ${KEYSTORE_PASSPHRASE}

2) Pipeline: render + apply, then deploy
# Render the template without printing secrets
export APP_SECRET_NAME="$(appSecretName)"
export NAMESPACE="$(namespace)"
envsubst < "$(Build.SourcesDirectory)/charts/<your-chart>/manifests/secret.yaml.tmpl" \
  | kubectl apply -f -

helm upgrade --install "$(releaseName)" "$CHART" \
  -n "$(namespace)" -f "$VALUES" \
  --set image.tag="$(imageTag)" \
  --set imagePullSecrets[0].name="$(jfrogPullSecretName)" \
  --set secret.secretname="$(appSecretName)" \
  --wait --atomic --history-max 10 --timeout 5m


…and map the variables:

env:
  ADMIN_PASSWORD: $(ADMIN_PASSWORD)
  KEYSTORE_PASSPHRASE: $(KEYSTORE_PASSPHRASE)


If your agent doesn’t have envsubst, you can install gettext-base once, or skip templating and use:

kubectl -n "$(namespace)" delete secret "$(appSecretName)" --ignore-not-found
kubectl -n "$(namespace)" create secret generic "$(appSecretName)" \
  --from-literal=ADMIN_PASSWORD="$(ADMIN_PASSWORD)" \
  --from-literal=KEYSTORE_PASSPHRASE="$(KEYSTORE_PASSPHRASE)"

Important notes (whichever option you pick)

Don’t commit secrets (even base64) to Git. Use ADO secret variables (or Key Vault–backed variable groups).

Your Deployment should reference the secret, e.g.:

envFrom:
  - secretRef:
      name: {{ .Values.secret.secretname | quote }}


or per-key via secretKeyRef.

Choose either Helm-templated Secret (Option A) or pipeline-applied Secret (Option B). Using both will create conflicts/duplication.

If you paste your current secret.yaml (with the keys/structure but without real values), I’ll convert it precisely to Option A or B based on your preference.
