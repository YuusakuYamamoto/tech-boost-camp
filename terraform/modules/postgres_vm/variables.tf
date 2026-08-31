variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where VM resources will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}

variable "subnet_id" {
  type        = string
  description = "OCID of the private subnet where the VM will be placed."
}

variable "db_nsg_id" {
  type        = string
  description = "OCID of the DB NSG to attach to the VM and add security rules to."
}

variable "app_nsg_id" {
  type        = string
  description = "OCID of the App NSG (used as source in PostgreSQL ingress rule)."
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR block of the VCN (used as source for SSH ingress rule)."
  default     = "10.0.0.0/16"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to inject into the VM for remote access."
}

variable "namespace" {
  type        = string
  description = "Object Storage namespace of the tenancy."
}

variable "config_bucket_name" {
  type        = string
  description = "Name of the bucket that stores docker-compose.yml."
}

variable "backup_bucket_name" {
  type        = string
  description = "Name of the bucket that stores PostgreSQL dumps."
}

variable "db_password_secret_id" {
  type        = string
  description = "OCID of the Vault secret holding the PostgreSQL password."
}
