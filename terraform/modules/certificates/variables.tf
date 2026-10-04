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
#
# 小数部は必須。oci raw-request で同一 JSON の当該フィールドだけを変えて実測した:
#   "...T00:00:00Z"      -> 400-InvalidParameter "Unable to process JSON input"
#   "...T00:00:00.000Z"  -> パース成功
#   "...T00:00:00.001Z"  -> パース成功
# API 自体は .000Z も受理するが、プロバイダーのバイナリには RFC3339Nano
# （秒の末尾のゼロを省く書式）が含まれており、その経路を通ると .000Z が Z に
# 戻って 1 行目と同じ失敗になる。どちらの書式でも安全な .001 以上を使う。
# 参考: https://github.com/oracle/terraform-provider-oci/issues/2024
variable "ca_validity_not_after" {
  type        = string
  description = "RFC 3339 timestamp when the CA certificate expires. Must carry non-zero milliseconds."
  default     = "2036-10-04T00:00:00.001Z"

  validation {
    condition     = can(regex("\\.[0-9]*[1-9][0-9]*Z$", var.ca_validity_not_after))
    error_message = "ca_validity_not_after must end with non-zero milliseconds (e.g., 2036-10-04T00:00:00.001Z); trailing zeros are stripped during serialization and rejected by the API."
  }
}

variable "certificate_validity_not_after" {
  type        = string
  description = "RFC 3339 timestamp when the leaf certificate expires. Must carry non-zero milliseconds."
  default     = "2027-10-04T00:00:00.001Z"

  validation {
    condition     = can(regex("\\.[0-9]*[1-9][0-9]*Z$", var.certificate_validity_not_after))
    error_message = "certificate_validity_not_after must end with non-zero milliseconds (e.g., 2027-10-04T00:00:00.001Z); trailing zeros are stripped during serialization and rejected by the API."
  }
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
