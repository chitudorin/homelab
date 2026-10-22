resource "hcloud_server" "node1" {
  name         = "node1"
  image        = "debian-12"
  location     = "fsn1"
  server_type  = "cx23"
  firewall_ids = [hcloud_firewall.node1firewall.id]
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  ssh_keys = [hcloud_ssh_key.mac.id, hcloud_ssh_key.win.id]
}


resource "hcloud_firewall" "node1firewall" {
  name = "node1-firewall"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "${local.my_ip}/32"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = [
      "${local.my_ip}/32"
    ]
  }

}


resource "hcloud_ssh_key" "mac" {
  name       = "mac-ssh-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInouqLC2CCAweQtwG+wKeXRd8Ga/Col6QComUfmMVZm"
}

resource "hcloud_ssh_key" "win" {
  name       = "win-ssh-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZU1owi9k3opPGYWVnd9T1u7IyUpxvvkkdbHwmU+Py5"
}

data "http" "own_ip" {
  url = "https://ipv4.wtfismyip.com/text"
}

locals {
  my_ip = chomp(data.http.own_ip.response_body)
}