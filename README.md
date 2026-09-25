# sapfire-gitops

Desired state for both Sapfire Manager environments. Argo CD reconciles the cluster
towards whatever is on `main` here; nothing is deployed by pushing from CI.

Generated from the application repo by `deploy/argocd/bootstrap-gitops.sh`. Application
source code lives there; this repo holds no source.

## Layout

```
base/              Kustomize base — client, server, worker, keycloak, both Postgres, backups, ingress
overlays/dev/      namespace sapfire-dev, dev hostnames        -> Application sapfire-dev
overlays/prod/     namespace sapfire-prod, replicas, storage   -> Application sapfire-prod
cluster-addons/    cert-manager ClusterIssuers (applied once, not synced)
argocd/apps/       AppProject sapfire (prod sync window) and the two Applications,
                   synced by the app-of-apps root
seal-secret.sh     helper for producing SealedSecret manifests
```

## Promote to prod

Prod syncs automatically, but only inside the nightly window of AppProject `sapfire`
(argocd/apps/project.yaml, default 02:00-04:00 Europe/Minsk).

```bash
cd overlays/prod
kustomize edit set image \
    sapfire/server=ghcr.io/sapfire-manager/sapfire-server:<sha> \
    sapfire/worker=ghcr.io/sapfire-manager/sapfire-worker:<sha> \
    sapfire/client=ghcr.io/sapfire-manager/sapfire-client:<sha> \
    sapfire/keycloak=ghcr.io/sapfire-manager/sapfire-keycloak:<sha>
git commit -am "promote <sha> to prod" && git push
```

Use a `<sha>` that has already run in dev. Dev is bumped automatically by Jenkins; prod
never is.

## Roll back

```bash
git revert <commit> && git push       # dev self-heals; prod applies it in the window
argocd app sync sapfire-prod          # emergency: manual sync is allowed outside the window
```

## Seal a secret

```bash
./seal-secret.sh sapfire-dev sapfire-db-credentials APP_DB_PASSWORD='...' \
    > overlays/dev/sealed-secrets/sapfire-db-credentials.yaml
```

Four secrets per environment, sealed independently for dev and prod. Plaintext never
enters this repo. Back up the Sealed Secrets controller's private key — without it every
sealed value here is unrecoverable.
