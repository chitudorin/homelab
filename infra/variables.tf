variable "state_passphrase" {
  description = "Passphrase that encrypts state and plan files (min 16 chars). Set via TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
}

# Kept out of the repo (it is public) and marked sensitive so plans in public
# Actions logs print "(sensitive value)" instead of the addresses.
variable "admin_cidrs" {
  description = "CIDRs allowed to reach the admin ports (SSH 22, Kubernetes API 6443), e.g. [\"203.0.113.7/32\"]. Set via TF_VAR_admin_cidrs."
  type        = list(string)
  sensitive   = true

  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0))])
    error_message = "admin_cidrs must be a non-empty list of CIDRs such as 203.0.113.7/32 or 2001:db8::/64."
  }
}
