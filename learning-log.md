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

Still to decide: where the OpenTofu state lives (it holds sensitive data and the repo is public).

## Decisions

| # | Decision | Why |
|---|----------|-----|
| 1 | Start with **1 control-plane node, schedulable** | etcd quorum: 2 nodes tolerate 0 failures, the same as 1, with more to break. Grow to 3 later. |
| 2 | **Talos Linux** as the Kubernetes OS | API-driven and immutable, so it fits IaC; good for the CV. Owner knows RKE2 already. |
| 3 | **OpenTofu** for infrastructure | Open-source Terraform fork; native client-side state encryption. |

## Concepts covered

- **Raft quorum**: majority is *strictly more than half*. Tolerated failures F = ⌊(N−1)/2⌋.
  1 node → 0, 2 → 0, 3 → 1, 4 → 1, 5 → 2. Even sizes add cost without adding tolerance,
  and risk split brain without the strict-majority rule.
- **Control plane down ≠ apps down**: running pods keep running, but nothing gets rescheduled,
  changed or reconciled (Flux included) until the API server is back.

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

## Cost notes

- **Hetzner** (discussed, no code yet): scale one node up rather than out; the price per GB
  of RAM drops with size, and each extra node adds an IPv4 and its own Talos overhead. Avoid
  paid add-ons: a Load Balancer (on one node, use a hostPort ingress), Volumes for bulk data
  (a Storage Box is far cheaper per TB) and Hetzner Backups (back up data, not the disk).
  A stopped server is still billed; only deleting it stops the bill. Cost-Optimized plans
  were unavailable in Oct 2026, so `tofu apply` may fail.
- **Claude inference** (setup changed by Claude, learn mode): work inline by default; a
  subagent starts cold and can't reuse the main session's prompt cache (the cache is per
  model and per exact prefix). Output tokens cost about 5× input, so short answers are
  cheaper. Cloud sessions block GitHub GraphQL (`gh pr create`) but allow REST (`gh api`);
  the shipper stays laptop-only until it uses REST. This log stays short; finished
  milestones move to `learning-archive.md`.
