variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where Vault resources will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}

variable "key_protection_mode" {
  type        = string
  description = "Protection mode for the master encryption key. SOFTWARE (free) or HSM (paid)."
  default     = "SOFTWARE"

  validation {
    condition     = contains(["SOFTWARE", "HSM"], var.key_protection_mode)
    error_message = "key_protection_mode must be either SOFTWARE or HSM."
  }
}

variable "secret_names" {
  type        = list(string)
  description = "List of secret names to create (e.g., [\"db-password\", \"session-secret\"])."
}
