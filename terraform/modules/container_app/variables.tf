variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where the container instance will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}

variable "role" {
  type        = string
  description = "Role of this container app (frontend or backend). Used in resource names and tags."
}

variable "subnet_id" {
  type        = string
  description = "OCID of the private subnet where the Container Instance will be placed."
}

variable "nsg_id" {
  type        = string
  description = "OCID of the App NSG to attach to the Container Instance and add the ingress rule to."
}

variable "lb_nsg_id" {
  type        = string
  description = "OCID of the LB NSG (used as source in the App NSG ingress rule)."
}

variable "load_balancer_id" {
  type        = string
  description = "OCID of the Load Balancer to register the backend with."
}

variable "backend_set_name" {
  type        = string
  description = "Name of the backend set to register this instance in."
}

# 固定値を割り当てる。LB Backend の ip_address は非 Updatable なため、IP を固定すると
# Container Instance が置き換わっても Backend に差分が出ない。サブネット内で未使用の
# アドレスを指定すること（使用中だと apply が失敗する）。
variable "private_ip" {
  type        = string
  description = "Static private IP to assign to the VNIC and register as the LB backend."
}

variable "port" {
  type        = number
  description = "Port the container listens on."
}

# latest は使わない。時間とともに変わる値を破壊的更新を引き起こす属性に渡すと、
# postgres_vm の source_id と同じ構図になる（Step 9 の問題 14）。
variable "image_url" {
  type        = string
  description = "Full container image URL including the tag. Do not use latest."
}

variable "shape" {
  type        = string
  description = "Container Instance shape."
  default     = "CI.Standard.A1.Flex"
}

variable "ocpu_count" {
  type        = number
  description = "Number of OCPUs."
  default     = 1
}

variable "memory_in_gbs" {
  type        = number
  description = "Memory in GB."
  default     = 4
}

variable "environment_variables" {
  type        = map(string)
  description = "Plain environment variables passed to the container. Never put secret values here."
  default     = {}
}

variable "vault_secret_ocids" {
  type        = map(string)
  description = "Map of logical name to Vault secret OCID. Each key is exposed as <KEY>_SECRET_OCID."
  default     = {}
}
