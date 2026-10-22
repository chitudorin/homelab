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

Status: code written by Claude (PR, learn mode) in `infra/`. Next: owner reviews, creates the
R2 bucket + tokens, runs `tofu init/apply/destroy/apply` on the laptop.

## Decisions

| # | Decision | Why |
|---|----------|-----|
| 1 | Start with **1 control-plane node, schedulable** | etcd quorum: 2 nodes tolerate 0 failures, the same as 1, with more to break. Grow to 3 later. |
| 2 | **Talos Linux** as the Kubernetes OS | API-driven and immutable, so it fits IaC; good for the CV. Owner knows RKE2 already. |
| 3 | **OpenTofu** for infrastructure | Open-source Terraform fork; native client-side state encryption. |
| 4 | **State in Cloudflare R2 + OpenTofu encryption** (pbkdf2 → AES-GCM, enforced) | Free (10 GB), S3-compatible, usable from any machine. Encryption means R2 only sees ciphertext. No state locking yet: single operator. |
| 5 | **Firewall**: 22 + 6443 from own IP only; 80/443 open | Admin surfaces never public; IP passed as a variable so it never lands in the repo. |

## Concepts covered

- **Raft quorum**: majority is *strictly more than half*. Tolerated failures F = ⌊(N−1)/2⌋.
  1 node → 0, 2 → 0, 3 → 1, 4 → 1, 5 → 2. Even sizes add cost without adding tolerance,
  and risk split brain without the strict-majority rule.
- **Control plane down ≠ apps down**: running pods keep running, but nothing gets rescheduled,
  changed or reconciled (Flux included) until the API server is back.

- **State**: OpenTofu's map of real resources to code. Lose it → OpenTofu forgets what it owns;
  leak it → whatever sensitive attributes it holds leak too. Remote backend + client-side encryption.
- **Config via env, not files**: provider token (`HCLOUD_TOKEN`), backend endpoint/creds
  (`AWS_*`), variables (`TF_VAR_*`). Lets the public repo stay secret-free.

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
- **Passphrase bootstrap**: where does the state passphrase live so a fresh laptop can run
  `tofu plan`? (Asked in session; unanswered.)
- **State locking**: what goes wrong if two `tofu apply` runs hit the same state at once?
- **Control-plane resources**: what does Minecraft (2–4 GB) do to etcd on a small schedulable
  control-plane node? Look into resource requests/limits and taints.
