variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where the Bastion will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names and freeform tags (e.g., tbcamp)."
}

variable "bastion_name" {
  type        = string
  description = "Name of the Bastion. Cannot be changed after creation."
}

variable "target_subnet_id" {
  type        = string
  description = "OCID of the subnet the Bastion connects to (the private subnet)."
}

variable "target_nsg_ids" {
  type        = map(string)
  description = "NSGs to add the SSH ingress rule to. Keys are descriptive labels (e.g., {\"app\" = \"ocid1.networksecuritygroup...\"})."
}

variable "client_cidr_block_allow_list" {
  type        = list(string)
  description = "Source CIDR blocks allowed to connect to Bastion sessions."
  default     = ["0.0.0.0/0"]
}
