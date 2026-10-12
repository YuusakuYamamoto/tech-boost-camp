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

# 疎通確認の段階では Docker Hub の公開イメージを指定する（Step 10a）。
# Step 10b で OCIR のイメージ URI に切り替える。
# latest は使わず、必ず具体的なタグを指定すること。
variable "backend_image_url" {
  type        = string
  description = "Full container image URL for the backend container instance, including the tag."
}
