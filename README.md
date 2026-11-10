# homelab

Homelab as code — a single-node Talos Linux Kubernetes cluster on Hetzner Cloud.

## Architecture

- **Control plane + worker**: one Hetzner `cx23` node in `nbg1`
- **OS**: Talos Linux (built from Image Factory via `hcloud-talos/imager`)
- **Infrastructure**: Terraform (`hcloud` + `imager` providers), state in R2
- **Firewall**: SSH/Talos API/K8s API restricted to your admin IP

## Layout

```
terraform/providers.tf    # provider declarations, backend, hcloud_token var
terraform/main.tf         # variables, Talos snapshot (imager), server, firewall
talos/controlplane.yaml.tmpl  # Talos machine config (substitute $NODE_IP)
.gitignore                # excludes tfstate, tfvars, generated kubeconfig/talosconfig
README.md                 # this file
```

## Prerequisites

- `TF_VAR_hcloud_token` set (Hetzner Cloud API token; read by the `hcloud_token` variable)
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
NODE_IP=$(terraform output -raw instance_ip)
echo $NODE_IP
```

## Bootstrap Talos + Kubernetes

From the Talos docs (gen config → apply-config → bootstrap → kubeconfig):

```bash
NODE_IP=$(terraform output -raw instance_ip)

# 1. Generate talosconfig + machine configs (includes cluster secrets)
talosctl gen config homelab "https://$NODE_IP:6443" \
  --install-disk /dev/sda \
  --output-dir talos

# 2. Apply the control-plane config (installs Talos to disk)
talosctl apply-config --insecure \
  --nodes "$NODE_IP" \
  --file talos/controlplane.yaml

# Point talosctl at the generated config before bootstrap/kubeconfig
export TALOSCONFIG=talos/talosconfig

# Wait for the node to reboot and become reachable, then:
talosctl bootstrap --nodes "$NODE_IP" --endpoints "$NODE_IP"

# 3. Fetch the kubeconfig
talosctl kubeconfig --nodes "$NODE_IP" --endpoints "$NODE_IP"

# 4. Verify
kubectl get nodes
kubectl get pods -A
```

To use a custom Talos image (e.g. from Image Factory), edit `machine.install.image` in the generated `talos/controlplane.yaml` before applying, or adapt `talos/controlplane.yaml.tmpl` and render it with `envsubst` (`$NODE_IP` is substituted automatically).

## Notes

- The Talos snapshot is built once and reused (`imager_image.talos_x86`, `prevent_destroy = true`).
- Sensitive ports (50000 Talos API, 6443 K8s API) are restricted to your admin IP.
- Generated `controlplane.yaml`, `kubeconfig`, and `talosconfig` are gitignored — do not commit them.
- R2 state backend: ensure `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (or equivalent) are available wherever `terraform` runs.

See issue #7 for context.