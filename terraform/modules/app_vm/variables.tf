variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where the application VM will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}

variable "subnet_id" {
  type        = string
  description = "OCID of the private subnet where the VM will be placed."
}

variable "nsg_id" {
  type        = string
  description = "OCID of the App NSG to attach to the VM and add ingress rules to."
}

variable "lb_nsg_id" {
  type        = string
  description = "OCID of the LB NSG (used as source in the App NSG ingress rules)."
}

variable "load_balancer_id" {
  type        = string
  description = "OCID of the Load Balancer to register the backends with."
}

variable "frontend_backend_set_name" {
  type        = string
  description = "Name of the backend set that serves the frontend."
}

variable "backend_backend_set_name" {
  type        = string
  description = "Name of the backend set that serves the API."
}

# サブネット内で未使用のアドレスを指定すること（使用中だと apply が失敗する）。
# LB Backend の ip_address と同じ値になる。
variable "private_ip" {
  type        = string
  description = "Static private IP assigned to the VNIC and registered as the LB backend."
}

variable "frontend_port" {
  type        = number
  description = "Port the Next.js container listens on."
  default     = 3000
}

variable "backend_port" {
  type        = number
  description = "Port the NestJS container listens on."
  default     = 4000
}

variable "ocpu_count" {
  type        = number
  description = "Number of OCPUs."
  default     = 1
}

variable "memory_in_gbs" {
  type        = number
  description = "Memory in GB."
  default     = 6
}

# Always Free のブロックストレージ枠（テナンシ全体で 200 GB）はすでに超過しているため、
# このボリュームは課金対象になる。
variable "boot_volume_size_in_gbs" {
  type        = number
  description = "Boot volume size in GB. 50 is the minimum for Oracle Linux."
  default     = 50
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to inject into the VM."
}

variable "namespace" {
  type        = string
  description = "Object Storage namespace of the tenancy."
}

variable "config_bucket_name" {
  type        = string
  description = "Name of the bucket that stores docker-compose.yml."
}

variable "db_host" {
  type        = string
  description = "Private IP of the PostgreSQL VM."
}

variable "db_password_secret_id" {
  type        = string
  description = "OCID of the Vault secret holding the database password."
}

variable "session_secret_id" {
  type        = string
  description = "OCID of the Vault secret holding the session secret."
}

# Dynamic Group のマッチングルールが参照する（ADR-0022）。
# ルート側で "<名前空間>.role" = "app" の形で渡す。
variable "defined_tags" {
  type        = map(string)
  description = "Defined tags applied to the instance. Keys are in <namespace>.<key> form."
  default     = {}
}
