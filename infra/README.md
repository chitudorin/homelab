# infra

OpenTofu root for the Hetzner infrastructure. State is stored in Cloudflare R2 and
encrypted client-side by OpenTofu before upload.

## One-time setup (Cloudflare dashboard)

1. **R2 → Create bucket**: name `homelab-tofu-state`, location hint *Eastern Europe (EEUR)*
   or *Western Europe (WEUR)* to sit near Hetzner.
2. **R2 → Manage API tokens → Create API token**:
   - Permission: *Object Read & Write*
   - Scope: *Apply to specific buckets only* → `homelab-tofu-state`
   - Copy the **Access Key ID**, **Secret Access Key** and the **S3 endpoint**
     (`https://<account-id>.r2.cloudflarestorage.com`). The secret is shown once.

The bucket is created by hand on purpose: it is the place state is stored, so it cannot
be managed by the state it holds (the bootstrap problem).

## Every shell session

Keep these in a password manager or an untracked `.envrc`, never in the repo:

```sh
export HCLOUD_TOKEN=...                       # Hetzner project token
export AWS_ACCESS_KEY_ID=...                  # R2 token access key
export AWS_SECRET_ACCESS_KEY=...              # R2 token secret
export AWS_ENDPOINT_URL_S3=https://<account-id>.r2.cloudflarestorage.com
export TF_VAR_state_passphrase=...            # >= 16 chars; lose it and the state is unreadable
```

Then:

```sh
cd infra
tofu init
tofu plan
```
