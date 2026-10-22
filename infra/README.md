# infra

OpenTofu for the Hetzner side: SSH key, firewall and the node(s).

## One-time setup

1. **Cloudflare R2**: create a bucket named `homelab-tofu-state`, then an R2 API token
   scoped to *Object Read & Write* on that bucket only.
2. **Hetzner**: create a read/write API token in the project.
3. Pick a state passphrase (16+ characters) and store it in your password manager.
   If you lose it, the state cannot be decrypted.

## Environment

Keep these in your password manager or a gitignored `.envrc`, never in the repo:

```sh
export HCLOUD_TOKEN=...
export AWS_ENDPOINT_URL_S3=https://<account-id>.r2.cloudflarestorage.com
export AWS_ACCESS_KEY_ID=...        # R2 token access key
export AWS_SECRET_ACCESS_KEY=...    # R2 token secret
export TF_VAR_state_passphrase=...
export TF_VAR_admin_cidr="$(curl -s https://ifconfig.me)/32"
```

## Run

```sh
cd infra
tofu init
tofu plan
tofu apply
tofu output server_ipv4
tofu destroy   # then apply again: the server is disposable
```
