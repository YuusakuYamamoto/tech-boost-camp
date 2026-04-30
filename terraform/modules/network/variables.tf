variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where the VCN will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the VCN."
  default     = "10.0.0.0/16"
}
