variable "state_passphrase" {
  description = "Passphrase that encrypts state and plan files (min 16 chars). Set via TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
}
