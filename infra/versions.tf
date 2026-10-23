terraform {
  required_version = ">= 1.10"

  # Full registry addresses: tofu treats "hetznercloud/hcloud" the same way, but
  # Renovate assumes registry.terraform.io for short names, can't match them to
  # the registry.opentofu.org entries in .terraform.lock.hcl, and never proposes
  # in-range updates.
  required_providers {
    hcloud = {
      source  = "registry.opentofu.org/hetznercloud/hcloud"
      version = "~> 1.70"
    }
  }

  # State lives in a Cloudflare R2 bucket, spoken to through the S3 API.
  # R2 is not AWS, so the AWS-specific checks are switched off.
  # Endpoint and credentials come from the environment (see infra/README.md):
  #   AWS_ENDPOINT_URL_S3, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
  backend "s3" {
    bucket = "homelab-tofu-state"
    key    = "infra/terraform.tfstate"
    region = "auto"

    use_lockfile   = true # lock with a .tflock object, no DynamoDB needed
    use_path_style = true

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }

  # Client-side encryption: the state is encrypted before it leaves the laptop,
  # so R2 (or anyone with the bucket keys) only ever sees ciphertext.
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "default" {
      keys = key_provider.pbkdf2.passphrase
    }

    state {
      method   = method.aes_gcm.default
      enforced = true
    }

    plan {
      method   = method.aes_gcm.default
      enforced = true
    }
  }
}
