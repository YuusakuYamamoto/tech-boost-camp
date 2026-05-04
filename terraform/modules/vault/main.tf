# =============================================================================
# Vault Module - Vault, Master Encryption Key, Secrets
# =============================================================================

# --- Vault ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/kms_vault
resource "oci_kms_vault" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.app_name}-vault"
  vault_type     = "DEFAULT"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "vault"
  }
}

# --- Master Encryption Key ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/kms_key
resource "oci_kms_key" "this" {
  compartment_id      = var.compartment_id
  display_name        = "${var.app_name}-master-key"
  management_endpoint = oci_kms_vault.this.management_endpoint
  protection_mode     = var.key_protection_mode

  key_shape {
    algorithm = "AES"
    length    = 32 # 256-bit
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "vault"
  }
}

# --- Secrets（箱のみ、実値は OCI CLI で後から投入） ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/vault_secret
resource "oci_vault_secret" "this" {
  for_each = toset(var.secret_names)

  compartment_id = var.compartment_id
  secret_name    = "${var.app_name}-${each.value}"
  vault_id       = oci_kms_vault.this.id
  key_id         = oci_kms_key.this.id
  description    = "Secret for ${each.value} (managed by Terraform, value injected via CLI)"

  secret_content {
    content_type = "BASE64"
    content      = base64encode("PLACEHOLDER")
  }

  # 実値は OCI CLI で投入するため、Terraform が上書きしないようにする
  lifecycle {
    ignore_changes = [secret_content]
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "vault"
  }
}
