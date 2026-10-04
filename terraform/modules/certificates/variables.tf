variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where the CA and certificate will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}

variable "kms_key_id" {
  type        = string
  description = "OCID of the HSM-protected asymmetric KMS key used by the CA. Software-protected keys are not supported."
}

variable "domain_name" {
  type        = string
  description = "Fully-qualified domain name the certificate is issued for."
}

# CA / 証明書はスケジュール削除のため、destroy 直後に同名で作り直せない。
# 作り直すときはこの値をインクリメントする。
variable "name_suffix" {
  type        = string
  description = "Suffix for the CA and certificate names. Increment when re-creating while a scheduled deletion is pending."
  default     = "01"
}

# timestamp() を使うと plan のたびに値が変わって差分が出続けるため、固定値を渡す。
# 両フィールドとも更新可能なので、後から変更しても再作成にはならない。
variable "ca_validity_not_after" {
  type        = string
  description = "RFC 3339 timestamp when the CA certificate expires."
  default     = "2036-10-04T00:00:00Z"
}

variable "certificate_validity_not_after" {
  type        = string
  description = "RFC 3339 timestamp when the leaf certificate expires."
  default     = "2027-10-04T00:00:00Z"
}

variable "subject_organization" {
  type        = string
  description = "Organization name (RDN O) in the certificate subject."
  default     = "tech-boost-camp"
}

variable "subject_country" {
  type        = string
  description = "Country name (RDN C) in the certificate subject."
  default     = "JP"
}
