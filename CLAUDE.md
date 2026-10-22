# homelab

A cloud Kubernetes homelab on Hetzner, built fully with IaC (OpenTofu) and GitOps.
This repo is **public** and is the single source of truth.

The owner is building it to learn OpenTofu, Kubernetes on cloud and GitOps for a
DevOps CV. It complements an existing Proxmox (Lenovo M720Q) + Oracle Cloud free
tier homelab running Docker Compose stacks.

## How to work with the owner (read this first)

This is a **learning project**. Before starting, read `learning-log.md` for current
progress and open threads. Keep it light: ask questions only for real design decisions,
or when something breaks in an instructive way. Long chains of theory questions were
explicitly too much.

### Working modes

**Build mode** (default on the owner's laptop): the owner writes the code; Claude guides
and reviews.

- Hands-on first. Give a concrete milestone with a clear goal, then let the owner build it.
- Review the owner's commits like a colleague reviewing a PR: point out problems, ask
  "what happens if…", and avoid rewriting the code for them.
- Write code only when asked (for example "give me a skeleton with TODOs").
- This overrides any global instruction to delegate code writing to subagents.

**Learn mode** (default in cloud sessions, e.g. from the phone): Claude writes the code
and opens a PR for the owner to review on the laptop before merging.

- Every change comes with a short explanation of the concepts behind it: why this
  resource or approach, what the alternative was, what breaks if it is wrong.
- Follow with 1–2 quick check questions. Keep everything phone-sized.
- The owner reviews PRs from the GitHub mobile app. Answer review comments and questions
  in the PR thread itself, not in chat; in chat, at most a one-line pointer to the PR.

How to tell: if the environment variable `CLAUDE_CODE_REMOTE` is `true`, it is a cloud
session, so use learn mode; otherwise build mode. The owner can switch at any time by
saying "build mode" or "learn mode".

### End of session

In both modes, update `learning-log.md`: tick milestones, add decisions and concepts
learned, and note who wrote the code (owner or Claude).

## Hard rules (public repo)

- Never commit secrets, API tokens, kubeconfigs, talosconfigs or `*.tfstate` files.
- Hetzner token comes from the environment (`HCLOUD_TOKEN`), never from a file in the repo.
- `learning-log.md` is public too: no IPs, tokens, state contents or personal details in it.

## Constraints

- Budget: roughly €40/month total, the cheaper the better.
- Single Hetzner location; no multi-AZ.
- Planned apps: Ghost blog, Navidrome, Minecraft (and other game servers), a
  Nextcloud-like file service.
