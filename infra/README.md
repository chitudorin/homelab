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
export TF_VAR_state_passphrase=...            # you invent it, see below
export TF_VAR_admin_cidrs='["<your-ip>/32"]'  # who may reach SSH and 6443, see below
```

`state_passphrase` is not issued by any service: you make it up once and reuse it on every
run. Generate one with `openssl rand -base64 32` and save it in your password manager.
If it is lost, the state can't be decrypted. The servers keep running, but OpenTofu no
longer knows it manages them: start a new state with a new passphrase and either
`tofu import` the resources or delete them in the Hetzner console and apply again.

`admin_cidrs` is the list of networks allowed to reach the admin ports (SSH 22, Kubernetes
API 6443). It is HCL list syntax inside single quotes; add more entries for other places,
e.g. `'["<home-ip>/32", "<ipv6-prefix>/64"]'`. Find your IPv4 with `curl -4 ifconfig.me`.
Keep it equal to the `TF_VAR_admin_cidrs` secret in GitHub, otherwise laptop and CI applies
flip the rule back and forth. It is never committed (public repo) and marked `sensitive`, so
plans show `(sensitive value)` instead of the addresses.

Then:

```sh
cd infra
tofu init
tofu plan
```

## GitHub Actions (`.github/workflows/tofu.yml`)

- **Pull request** touching `infra/**`: `fmt -check` and `validate` (no secrets), then a
  read-only `plan`, shown in the run's summary page. Skipped for PRs from forks.
- **Push to `main`** (or *Run workflow* by hand): `plan`, then `apply` of exactly that saved
  plan, after you approve it. Nothing to apply → no approval asked.

### One-time setup (repo → Settings → Environments)

Secrets live on **environments**, not at repository level: a job only gets an
environment's secrets if it names that environment, and only after the environment's rules
(approval, allowed branches) pass. Create two:

| Environment | Protection rules | Tokens in it |
|---|---|---|
| `infra-plan` | none (runs on every PR) | **read-only**: Hetzner token with *Read* permission, R2 token with *Object Read only* on `homelab-tofu-state` |
| `infra-apply` | *Required reviewers*: you; *Deployment branches*: selected → `main` only | read & write (the ones you use on the laptop) |

Add these secrets, with the same names, in **both** environments:

| Secret | `infra-plan` | `infra-apply` |
|---|---|---|
| `HCLOUD_TOKEN` | Hetzner *Read* token | Hetzner *Read & Write* token |
| `AWS_ACCESS_KEY_ID` | R2 read-only token key | R2 read & write token key |
| `AWS_SECRET_ACCESS_KEY` | R2 read-only token secret | R2 read & write token secret |
| `AWS_ENDPOINT_URL_S3` | R2 S3 endpoint | same |
| `TF_VAR_state_passphrase` | state passphrase | same |
| `TF_VAR_admin_cidrs` | e.g. `["<your-ip>/32"]` | same |

Leave the repository-level secrets empty. Actions logs on a public repo are public: never
`echo` a secret or run `tofu show -json`/`tofu output` on sensitive values in a workflow.

When your home IP changes: update `TF_VAR_admin_cidrs` in both environments (and your
shell), then *Actions → tofu → Run workflow* on `main` and approve the apply.
