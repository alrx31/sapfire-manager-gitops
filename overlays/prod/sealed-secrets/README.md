# Sealed Secrets — sapfire-prod

Empty until you run `../../../seal-secret.sh` once against a cluster that has
the Sealed Secrets controller installed (see `../../../README.md` "Secrets").
Generate all five required `SealedSecret` manifests into this directory, then
uncomment the `sealed-secrets` entry in `../kustomization.yaml`'s `resources:`
list.

Required secrets (name → keys):

- `sapfire-db-credentials` → `APP_DB_PASSWORD`
- `keycloak-db-credentials` → `KEYCLOAK_DB_PASSWORD`
- `keycloak-admin-credentials` → `KEYCLOAK_ADMIN_PASSWORD`
- `keycloak-client-secret` → `KEYCLOAK_ADMIN_CLIENT_SECRET`
- `rabbitmq-credentials` → `RABBITMQ_PASSWORD` (the broker's `sapfire` user; read by the
  rabbitmq StatefulSet and the Worker)

Until these exist, `kubectl apply -k deploy/k8s/overlays/prod` brings up every
resource except working Secrets — the client/server/keycloak Deployments will
sit at `CreateContainerConfigError` until the SealedSecrets are applied. This
is expected on a brand-new checkout.
