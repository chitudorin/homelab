# The token is read from the HCLOUD_TOKEN env var, never from a file.
provider "hcloud" {}

locals {
  name = "homelab"
}

resource "hcloud_ssh_key" "admin" {
  name       = "${local.name}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_firewall" "node" {
  name = "${local.name}-node"

  # Admin access: only from your own IP.
  rule {
    description = "SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = [var.admin_cidr]
  }

  rule {
    description = "Kubernetes API"
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = [var.admin_cidr]
  }

  # Public web traffic for the apps.
  rule {
    description = "HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "node" {
  name        = "${local.name}-cp-1"
  server_type = var.server_type
  location    = var.location
  # Placeholder OS to prove the server is disposable; Talos replaces it in milestone 2.
  image        = "ubuntu-24.04"
  ssh_keys     = [hcloud_ssh_key.admin.id]
  firewall_ids = [hcloud_firewall.node.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
