variable "talos_version" {
  type        = string
  default     = "v1.14.5"
  description = "Talos Linux version to deploy"
}

variable "location" {
  type        = string
  default     = "nbg1"
  description = "Hetzner Cloud location"
}

variable "server_type" {
  type        = string
  default     = "cx23"
  description = "Hetzner Cloud server type"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key content for the node"
}

data "http" "personal_ip" {
  url = "https://ipv4.wtfismyip.com/text"
}

locals {
  admin_ip = "${chomp(data.http.personal_ip.response_body)}/32"
}

# Build a Talos snapshot from the official Image Factory image.
# This is the recommended way to run Talos on Hetzner Cloud; the public
# Talos ISO can boot in "metal" mode and breaks hcloud-cloud-controller-manager.
# See: https://docs.siderolabs.com/talos/v1.14/platform-specific-installations/cloud-platforms/hetzner
resource "imager_image" "talos_x86" {
  image_url    = "https://factory.talos.dev/image/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba/${var.talos_version}/hcloud-amd64.raw.xz"
  architecture = "x86"
  location     = var.location

  labels = {
    version = var.talos_version
    os      = "talos"
    creator = "homelab"
  }

  lifecycle {
    # prevent_destroy keeps the Talos snapshot stable across applies.
    # When bumping var.talos_version, image_url changes and Terraform wants to
    # replace the image — prevent_destroy blocks that. To upgrade, temporarily
    # remove this line, apply, then re-add it (or manage the snapshot out-of-band).
    prevent_destroy = true
  }

  timeouts {
    create = "20m"
  }
}

resource "hcloud_ssh_key" "main" {
  name       = "my-ssh-key"
  public_key = var.ssh_public_key
}

# Talos cluster firewall. Sensitive ports (50000 Talos API, 6443 Kubernetes API)
# are restricted to the admin IP; internal ports (kubelet, etcd, VXLAN, trustd)
# are scoped the same way for a single-node homelab. See Talos ingress-firewall docs.
# NOTE: when adding worker nodes or a load balancer, scope internal-port rules
# to the node/private network CIDR instead of the admin IP, otherwise cross-node
# traffic will be silently blocked by the Hetzner firewall.
resource "hcloud_firewall" "talos" {
  name = "talos-firewall"
  labels = {
    os = "talos"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = [local.admin_ip]
    description = "SSH"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "50000"
    source_ips  = [local.admin_ip]
    description = "Talos API (apid)"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = [local.admin_ip]
    description = "Kubernetes API"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "10250"
    source_ips  = [local.admin_ip]
    description = "kubelet"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2379-2380"
    source_ips  = [local.admin_ip]
    description = "etcd"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "50001"
    source_ips  = [local.admin_ip]
    description = "trustd maintenance"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "4789"
    source_ips  = [local.admin_ip]
    description = "VXLAN (CNI)"
  }
}

resource "hcloud_server" "node1" {
  name         = "node1"
  image        = imager_image.talos_x86.id
  server_type  = var.server_type
  location     = var.location
  firewall_ids = [hcloud_firewall.talos.id]
  ssh_keys     = [hcloud_ssh_key.main.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

output "instance_ip" {
  value       = hcloud_server.node1.ipv4_address
  description = "IPv4 address of the Talos control-plane node"
}

output "talos_endpoint" {
  value       = "https://${hcloud_server.node1.ipv4_address}:6443"
  description = "Talos / Kubernetes API endpoint"
}

output "talos_image_id" {
  value       = imager_image.talos_x86.id
  description = "Hetzner image ID of the Talos snapshot"
}