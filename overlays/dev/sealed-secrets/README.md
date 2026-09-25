# Sealed Secrets — sapfire-dev

All five `SealedSecret` manifests are populated and wired into
`kustomization.yaml`. They were sealed on 25.09.2026 against the local Docker Desktop cluster's
controller; a new cluster has a new controller key, so every file here has to be resealed
with fresh values (`../../../seal-secret.sh sapfire-dev <name> KEY=...`).

Secrets (name → key):

- `sapfire-db-credentials` → `APP_DB_PASSWORD`
- `keycloak-db-credentials` → `KEYCLOAK_DB_PASSWORD`
- `keycloak-admin-credentials` → `KEYCLOAK_ADMIN_PASSWORD`
- `keycloak-client-secret` → `KEYCLOAK_ADMIN_CLIENT_SECRET`
- `rabbitmq-credentials` → `RABBITMQ_PASSWORD`

Plaintext values are nowhere but in the cluster:
`kubectl -n sapfire-dev get secret <name> -o jsonpath='{.data.<KEY>}' | base64 -d`.

`keycloak-client-secret` is also consumed by the realm-sync Job, not just the
server: `realm-export.json` is committed to git, so the `sapfire-api` client
secret cannot be a literal there. The export carries
`"secret": "$(env:KEYCLOAK_ADMIN_CLIENT_SECRET)"` and the Job sets
`IMPORT_VAR_SUBSTITUTION_ENABLED=true`, which keycloak-config-cli resolves
before parsing the JSON — so the sealed value reaches Keycloak and git keeps no
plaintext. Rotating this secret therefore requires re-running the realm-sync
Job, or Keycloak keeps serving the previous value.

## Re-sealing

These values are sealed against one specific controller keypair. A controller
reinstalled without restoring its key generates a new one, and every file here
becomes permanently undecryptable — re-seal all four rather than trying to
recover them:

```bash
./seal-secret.sh sapfire-dev <secret-name> <KEY>='<value>' \
  > overlays/dev/sealed-secrets/<secret-name>.yaml
```

Job specs are immutable, so after re-sealing anything the realm-sync and
migration Jobs must be deleted before re-applying:

```bash
kubectl delete job server-migrate keycloak-realm-sync -n sapfire-dev --ignore-not-found
```

Until these Secrets exist, every Pod except `client` sits at
`CreateContainerConfigError` — expected on a brand-new cluster, and the reason
the Sealed Secrets controller must be installed first (see
`../../../README.md` "Secrets").
