variable "region" {
  type        = string
  description = "OCI region where resources will be created (e.g., ap-tokyo-1)."
}

variable "tenancy_id" {
  type        = string
  description = "OCID of the tenancy."
}

variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where resources will be created (tbcamp compartment)."
}
