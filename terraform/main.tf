terraform {
  backend "s3" {
    bucket = "homelab"
    key    = "terraform.tfstate"
    endpoints = {
      s3 = "https://d3c4d0acfe187ae847011587c42c5f91.eu.r2.cloudflarestorage.com"
    }
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

resource "hcloud_firewall" "myfirewall" {
  name = "my-firewall"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "${chomp(data.http.personal_ip.response_body)}/32"
    ]
    ]
  }

}

resource "hcloud_ssh_key" "main" {
  name       = "my-ssh-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "hcloud_server" "node1" {
  name         = "node1"
  image        = "debian-12"
  server_type  = "cx23"
  location     = "nbg1"
  firewall_ids = [hcloud_firewall.myfirewall.id]
  ssh_keys     = [hcloud_ssh_key.main.id]
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

output "instance_ip" {
  value = hcloud_server.node1.ipv4_address
}

data "http" "personal_ip" {
  url = "https://ipv4.wtfismyip.com/text"
}