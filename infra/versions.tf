terraform {
  # 1.8+ allows variables inside the encryption block below (early evaluation).
  required_version = ">= 1.8.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.52"
    }
  }

  # State lives in a Cloudflare R2 bucket (S3-compatible API).
  # Nothing account-specific is committed: the endpoint and credentials come from env vars:
  #   AWS_ENDPOINT_URL_S3   = https://<account-id>.r2.cloudflarestorage.com
  #   AWS_ACCESS_KEY_ID     = R2 API token access key
  #   AWS_SECRET_ACCESS_KEY = R2 API token secret
  backend "s3" {
    bucket = "homelab-tofu-state"
    key    = "foundation/terraform.tfstate"
    region = "auto" # R2 ignores regions, but the S3 backend requires one

    # R2 is not AWS: skip the AWS-only checks the backend does by default.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  # Client-side encryption: the state is encrypted before it leaves the laptop,
  # so neither R2 nor anyone with bucket access can read it.
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }

    state {
      method   = method.aes_gcm.main
      enforced = true # refuse to ever write unencrypted state
    }

    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}
