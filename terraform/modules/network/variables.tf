variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where network resources will be created."
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

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet (e.g., 10.0.1.0/24)."
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet (e.g., 10.0.2.0/24)."
}
