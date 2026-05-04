variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where the bucket will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}
