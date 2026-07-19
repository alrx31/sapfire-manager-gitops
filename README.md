# sapfire-gitops

Desired state for both Sapfire Manager environments. Argo CD reconciles the cluster
towards whatever is on `main` here; nothing is deployed by pushing from CI.

Generated from the application repo by `deploy/argocd/bootstrap-gitops.sh`. Application
source code lives there; this repo holds no source.

## Layout

```
base/              Kustomize base — client, server, keycloak, both Postgres, ingress
overlays/dev/      namespace sapfire-dev, dev hostnames        -> Application sapfire-dev
overlays/prod/     namespace sapfire-prod, replicas, storage   -> Application sapfire-prod
cluster-addons/    cert-manager ClusterIssuers (applied once, not synced)
argocd/apps/       the two Application resources, synced by the app-of-apps root
seal-secret.sh     helper for producing SealedSecret manifests
```

## Promote to prod

Prod has no automated sync — the manual sync *is* the approval gate.

```bash
cd overlays/prod
kustomize edit set image \
    sapfire/server=ghcr.io/sapfire-manager/sapfire-server:<sha> \
    sapfire/client=ghcr.io/sapfire-manager/sapfire-client:<sha> \
    sapfire/keycloak=ghcr.io/sapfire-manager/sapfire-keycloak:<sha>
git commit -am "promote <sha> to prod" && git push
argocd app sync sapfire-prod
```

Use a `<sha>` that has already run in dev. Dev is bumped automatically by Jenkins.

## Roll back

```bash
git revert <commit> && git push       # dev self-heals; prod needs an explicit sync
```

## Seal a secret

Requires the Sealed Secrets controller, applied by hand once per cluster (no
Application syncs `cluster-addons/`):

```bash
kubectl apply -k cluster-addons/sealed-secrets
kubectl -n kube-system rollout status deploy/sealed-secrets-controller
```

```bash
./seal-secret.sh sapfire-dev sapfire-db-credentials APP_DB_PASSWORD='...' \
    > overlays/dev/sealed-secrets/sapfire-db-credentials.yaml
```

Re-sealing `keycloak-client-secret` also requires deleting the realm-sync Job so
it re-runs — Keycloak otherwise keeps serving the previous value:

```bash
kubectl delete job keycloak-realm-sync -n sapfire-dev --ignore-not-found
```

Four secrets per environment, sealed independently for dev and prod. Plaintext never
enters this repo. Back up the Sealed Secrets controller's private key — without it every
sealed value here is unrecoverable.
