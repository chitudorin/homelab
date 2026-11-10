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

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }
    imager = {
      source  = "hcloud-talos/imager"
      version = "~> 0.1"
    }
  }
}

variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API token (set via HCLOUD_TOKEN or TF_VAR_hcloud_token)"
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "imager" {
  token = var.hcloud_token
}
