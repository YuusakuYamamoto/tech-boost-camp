variable "tenancy_id" {
  type        = string
  description = "OCID of the tenancy (required for Dynamic Group creation at root level)."
}

variable "compartment_id" {
  type        = string
  description = "OCID of the app compartment referenced in matching rules and policy statements."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}

variable "backup_bucket_name" {
  type        = string
  description = "Name of the Object Storage bucket for PostgreSQL backups."
}
