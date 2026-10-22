variable "state_passphrase" {
  description = "Passphrase for OpenTofu state encryption (min 16 chars). Set via TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.10/32. Only this can reach SSH and the Kubernetes API."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be a valid CIDR, e.g. 203.0.113.10/32."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key to install on the server."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "location" {
  description = "Hetzner location (single location, no multi-AZ)."
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner server type. cx23 = Cost-Optimized, 2 vCPU / 4 GB."
  type        = string
  default     = "cx23"
}
