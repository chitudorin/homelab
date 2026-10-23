# Learning log

Running record of progress, decisions and open questions. Update at the end of each session,
and note who wrote the code (owner or Claude).

## Owner background

- Kubernetes: has used it; RKE2 at a previous company.
- GitOps: surface-level ArgoCD at work; FluxCD in
  [raiffeisen-homework](https://github.com/chitudorin/raiffeisen-homework)
  (RKE2 + Flux + ingress-nginx + cert-manager).
- Terraform/OpenTofu: none yet, learning it here.

## Roadmap

1. [x] **Foundation**: OpenTofu provisions a Hetzner server, firewall and SSH key; state stored safely
2. [ ] **Cluster**: Talos single node with schedulable workloads, kubeconfig retrieved
3. [ ] **GitOps**: Flux (or Argo CD) bootstrapped and managing itself from this repo
4. [ ] **Secrets**: a workable answer for a public repo (SOPS / External Secrets + Infisical or GCP)
5. [ ] **Platform**: ingress, TLS, DNS, storage (Hetzner CSI), backups, observability
6. [ ] **Apps**: Ghost, Navidrome, Minecraft, file storage
7. [ ] **HA**: grow to 3 control-plane nodes and watch etcd form a quorum

## Current milestone: 1. Foundation

Goal: `tofu apply` creates an SSH key, a firewall (SSH + 6443 from own IP only, 80/443
open) and one Cost-Optimized server, and outputs its IPv4 address. Then `tofu destroy`
and apply again to prove the server is disposable.

- [x] State backend: Cloudflare R2 + OpenTofu client-side encryption (`infra/versions.tf`, written by Claude, PR for owner review)
- [x] Owner: create the R2 bucket + scoped API token by hand, run `tofu init` (see `infra/README.md`)
- [x] Owner: SSH keys, firewall and server resources, IPv4 output (`infra/main.tf`, written by owner, PR #6)
- [x] Owner: `tofu destroy` and re-apply to prove the server is disposable
- [x] Provider updates: Renovate with a 7-day cooldown (`renovate.json5`, full provider addresses in `infra/versions.tf`, written by Claude, PR for owner review)
- [ ] Owner: after merging, install the Renovate GitHub App on this repo only
- [x] Tofu in GitHub Actions: PR plan, approved apply on `main`, firewall IPs from a secret (`.github/workflows/tofu.yml`, `infra/`, written by Claude, PR for owner review)
- [ ] Owner: create the `infra-plan` / `infra-apply` environments, read-only tokens and secrets (see `infra/README.md`), export `TF_VAR_admin_cidrs` locally

## Decisions

| # | Decision | Why |
|---|----------|-----|
| 1 | Start with **1 control-plane node, schedulable** | etcd quorum: 2 nodes tolerate 0 failures, the same as 1, with more to break. Grow to 3 later. |
| 2 | **Talos Linux** as the Kubernetes OS | API-driven and immutable, so it fits IaC; good for the CV. Owner knows RKE2 already. |
| 3 | **OpenTofu** for infrastructure | Open-source Terraform fork; native client-side state encryption. |
| 4 | State in **Cloudflare R2** (S3 backend) | Free tier (10 GB, no egress fees), account already exists for DNS. Locking via `use_lockfile`, no DynamoDB. |
| 5 | **Encrypt state client-side** (pbkdf2 + AES-GCM, `enforced = true`) | State holds secrets in plain text; encryption means a leaked bucket key exposes only ciphertext. |
| 6 | State bucket **created by hand**, not by Tofu | Bootstrap problem: the bucket that stores state can't be managed by that same state. |
| 7 | ~~Admin ports (22, 6443) allowed from an **auto-detected IP** (`http` data source)~~ **Superseded by 10.** | Low risk: keys/certs still guard the ports. Accepted costs: the rule follows whoever last ran apply (lockout from elsewhere), and IP changes need a re-apply (in-place update, no rebuild). Not suitable for CI applies. |
| 8 | **Renovate** with `minimumReleaseAge: 7 days` for provider updates | A cooldown lets others catch a hijacked release before it reaches the lock file. Renovate reads OpenTofu release dates; Dependabot's OpenTofu support is community-maintained. Security fixes skip the wait. |
| 9 | Provider `source` written as **full addresses** (`registry.opentofu.org/...`) | Renovate matches providers to lock file entries by registry host and assumes `registry.terraform.io` for short names, so it never proposed in-range updates. Tofu resolves both forms to the same address: no lock or state change. |
| 10 | Admin ports allowed from **`admin_cidrs`**, a `sensitive` variable set from the environment / a GitHub secret | Works the same from laptop and CI (an auto-detected IP would be the runner's, locking the owner out). Never in the repo, and redacted in public Actions logs. Cost: when the home IP changes, update the secret and re-run. |
| 11 | **Tofu runs in GitHub Actions**: plan on PRs, apply on `main` after the owner approves | Infra changes become reviewed merges, not laptop commands. Local applies still work; laptop and CI share state and its lock. |
| 12 | **Two environments**: `infra-plan` (no approval, read-only tokens) and `infra-apply` (owner approval, `main` only, read/write tokens) | Environment secrets reach a job only after the environment's rules pass. Plans need state but not write access, so PRs get read-only tokens without an approval click; anything that can change infra waits for the owner. |
| 13 | Apply runs the **saved, encrypted plan** from the same run | You approve the plan you saw; if state changed meanwhile, tofu rejects the stale plan instead of applying something else. No changes → no approval asked. |

## Concepts covered

- **Raft quorum**: majority is *strictly more than half*. Tolerated failures F = ⌊(N−1)/2⌋.
  1 node → 0, 2 → 0, 3 → 1, 4 → 1, 5 → 2. Even sizes add cost without adding tolerance,
  and risk split brain without the strict-majority rule.
- **Control plane down ≠ apps down**: running pods keep running, but nothing gets rescheduled,
  changed or reconciled (Flux included) until the API server is back.

- **Remote state + locking**: the backend is where state lives; the lock (`.tflock` object
  in R2) stops two `apply` runs from writing state at the same time and corrupting it.
- **Two layers of protection**: R2 token scope (who can read the bucket) and state
  encryption (what they can read). The passphrase is now the single key to recover state.
  Stolen bucket keys: an attacker can delete or overwrite state but not read it, and can't
  edit it undetected (AES-GCM is authenticated, so tampered state fails to decrypt).
- **Lock file vs state file**: `.terraform.lock.hcl` pins exact provider versions and their
  checksums, so every machine and CI run gets the same binaries (protects against supply-chain
  attacks, e.g. a tampered provider download). It holds no secrets, so it
  is committed. State describes real infrastructure and holds secrets, so it never is.
- **`init` vs `init -upgrade`**: plain `init` installs exactly what the lock file says and
  checks the hashes (run it after merging an update PR). `-upgrade` ignores the lock and
  takes the newest version the constraint allows, even one released minutes ago, which
  skips the cooldown.
- **Pessimistic constraint `~>`**: only the last number written may grow. `~> 1.70` allows
  1.71 and 1.70.1 but not 2.0; `~> 3.6.3` allows patches only. Renovate updates in-range
  versions in the lock file only, and proposes a new major in a separate PR that rewrites
  the constraint. Owner got both right.

- **Study aid**: Claude made an interactive flashcard deck (21 cards) covering every line of
  PR #4: backend, locking, encryption, variables, providers, lock file.

- **Forces replacement**: some attributes can only be set at creation. Changing `ssh_keys`
  on `hcloud_server` is a `-/+` (destroy and recreate), because keys are injected by
  cloud-init at first boot. Always read the plan for `-/+` before typing yes.
- **Locals vs variables**: variables are a module's inputs; locals are internal named
  values. Fixed server attributes belong in locals.
- **Renaming has a cost**: renaming a resource address makes Tofu destroy and recreate it
  unless a `moved {}` block maps old → new. Renaming an output is free, but breaks anything
  that reads the old name.

- **CI for IaC** (PR #10): `pull_request` runs the PR's code without secrets for forks;
  `pull_request_target` runs with secrets in the base repo's context, which is how public
  repos get their secrets stolen, so it is never used here. Environments scope secrets and
  add approval + branch rules. `permissions: contents: read` limits the job token.
  `concurrency` stops two runs overlapping; the state lock protects state even across
  laptop and CI. Actions are pinned by commit SHA because tags can be moved; Renovate
  updates the SHAs. `sensitive = true` redacts values in plans, and GitHub's own masking
  would miss them (it only masks the whole secret string, not each list element).

## Open threads (unanswered questions to revisit)

- **Talos API from CI** (before milestone 2c): the `siderolabs/talos` provider must reach
  ports 50000 and 6443 from wherever apply runs, and GitHub-hosted runners have changing IPs.
  Options: open 50000/6443 to the world and rely on Talos/Kubernetes mTLS; add the runner's
  IP with the hcloud CLI for the job and remove it after; Tailscale on the runner; a
  self-hosted runner on the Proxmox homelab. Recommendation in PR #10; decide before 2c.

- **GitOps vs "config in Git"**: what does a pull-based controller (Flux) give you that a CI
  job running `kubectl apply` doesn't? (Hint: drift after a manual `kubectl edit`.) Which tool
  owns servers and which owns in-cluster state? Who installs Flux?
- **Secrets bootstrap**: any external secrets manager needs a credential to read it. How does
  that first credential reach a fresh cluster? With SOPS, what is committed and what never is?
  (In raiffeisen-homework the basic-auth secret was created with `kubectl` by hand, so Flux
  would not recreate it.)
- **Data vs config**: Git rebuilds configuration, not Ghost posts or Nextcloud files. Where
  do backups live, and how are they restored?
- **Control-plane resources**: what does Minecraft (2–4 GB) do to etcd on a small schedulable
  control-plane node? Look into resource requests/limits and taints.
