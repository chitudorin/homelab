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

1. [ ] **Foundation**: OpenTofu provisions a Hetzner server, firewall and SSH key; state stored safely
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
- [ ] Owner: create the R2 bucket + scoped API token by hand, run `tofu init` (see `infra/README.md`)
- [ ] Owner: SSH key, firewall and server resources, IPv4 output; destroy and re-apply

## Decisions

| # | Decision | Why |
|---|----------|-----|
| 1 | Start with **1 control-plane node, schedulable** | etcd quorum: 2 nodes tolerate 0 failures, the same as 1, with more to break. Grow to 3 later. |
| 2 | **Talos Linux** as the Kubernetes OS | API-driven and immutable, so it fits IaC; good for the CV. Owner knows RKE2 already. |
| 3 | **OpenTofu** for infrastructure | Open-source Terraform fork; native client-side state encryption. |
| 4 | State in **Cloudflare R2** (S3 backend) | Free tier (10 GB, no egress fees), account already exists for DNS. Locking via `use_lockfile`, no DynamoDB. |
| 5 | **Encrypt state client-side** (pbkdf2 + AES-GCM, `enforced = true`) | State holds secrets in plain text; encryption means a leaked bucket key exposes only ciphertext. |
| 6 | State bucket **created by hand**, not by Tofu | Bootstrap problem: the bucket that stores state can't be managed by that same state. |

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
  checksums, so every machine and CI run gets the same binaries. It holds no secrets, so it
  is committed. State describes real infrastructure and holds secrets, so it never is.

## Open threads (unanswered questions to revisit)

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
