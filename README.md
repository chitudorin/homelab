# homelab

Homelab as code — a single-node Talos Linux Kubernetes cluster on Hetzner Cloud.

## Architecture

- **Control plane + worker**: one Hetzner `cx23` node in `nbg1`
- **OS**: Talos Linux (built from Image Factory via `hcloud-talos/imager`)
- **Infrastructure**: Terraform (`hcloud` + `imager` providers), state in R2
- **Firewall**: SSH/Talos API/K8s API restricted to your admin IP

## Layout

```
terraform/main.tf     # Hetzner server, firewall, Talos snapshot (imager)
talos/controlplane.yaml.tmpl  # Talos machine config (substitute NODE_IP)
README.md             # this file
```

## Prerequisites

- `HCLOUD_TOKEN` set (Hetzner Cloud API token)
- `terraform >= 1.9`
- `talosctl` and `kubectl` installed locally
- `~/.ssh/id_ed25519.pub` present (referenced by `hcloud_ssh_key.main`)

## Deploy

```bash
cd terraform

# Initialize providers and backend
terraform init

# Review the plan
terraform plan

# Apply (uploads the Talos image + creates the node)
terraform apply

# Grab the node IP
terraform output -raw instance_ip
```

## Bootstrap Talos + Kubernetes

From the Talos docs (gen config → apply-config → bootstrap → kubeconfig):

```bash
NODE_IP=$(terraform output -raw instance_ip)

# 1. Generate machine configs + talosconfig
talosctl gen config homelab "https://$NODE_IP:6443" \
  --install-disk /dev/sda \
  --output-dir talos

# 2. Apply the control-plane config (installs Talos to disk)
talosctl apply-config --insecure \
  --nodes "$NODE_IP" \
  --file talos/controlplane.yaml

# Wait for the node to reboot and become reachable, then:
talosctl bootstrap --nodes "$NODE_IP" --endpoints "$NODE_IP"

# 3. Fetch the kubeconfig
talosctl kubeconfig --nodes "$NODE_IP" --endpoints "$NODE_IP"

# 4. Verify
kubectl get nodes
kubectl get pods -A
```

## Notes

- The Talos snapshot is built once and reused (`imager_image.talos_x86`, `prevent_destroy = true`).
- Sensitive ports (50000 Talos API, 6443 K8s API) are restricted to your admin IP.
- Generated `controlplane.yaml`, `kubeconfig`, and `talosconfig` are gitignored — do not commit them.
- R2 state backend: ensure `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (or equivalent) are available wherever `terraform` runs.

See issue #7 for context.
