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

variable "auth" {
  type    = string
  default = "APIKey"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to inject into the PostgreSQL VM."
}

variable "notification_email" {
  type        = string
  description = "Email address that receives budget alerts and alarm notifications."

  # public リポジトリであり、plan 出力は PR コメントにそのまま貼られる。
  # sensitive にすることで endpoint / recipients が (sensitive value) になる。
  sensitive = true
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget as a whole number, in the currency of the tenancy's rate card (JPY for this tenancy)."
}
