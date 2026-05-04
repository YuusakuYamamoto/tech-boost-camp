# =============================================================================
# IAM Module - Dynamic Groups + Runtime Policy
# =============================================================================

# Compartment 名を Policy statement で使用するために取得
data "oci_identity_compartment" "this" {
  id = var.compartment_id
}

# --- Dynamic Groups（テナンシーレベルで作成 — OCI の仕様） ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_dynamic_group
resource "oci_identity_dynamic_group" "app" {
  compartment_id = var.tenancy_id
  name           = "${var.app_name}-app-instances"
  description    = "Container Instances in ${var.app_name} compartment for Instance Principal auth"
  matching_rule  = "All {resource.type = 'computecontainerinstance', resource.compartment.id = '${var.compartment_id}'}"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "iam"
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_dynamic_group
resource "oci_identity_dynamic_group" "db" {
  compartment_id = var.tenancy_id
  name           = "${var.app_name}-db-instances"
  description    = "Compute Instances in ${var.app_name} compartment for Instance Principal auth"
  matching_rule  = "All {resource.type = 'instance', resource.compartment.id = '${var.compartment_id}'}"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "iam"
  }
}

# --- Runtime Policy（tbcamp compartment に配置） ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_policy
resource "oci_identity_policy" "runtime" {
  compartment_id = var.tenancy_id
  name           = "${var.app_name}-runtime-policy"
  description    = "Runtime permissions for ${var.app_name} Container Instances and VMs"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to read secret-family in compartment ${data.oci_identity_compartment.this.name}",
    "Allow dynamic-group ${oci_identity_dynamic_group.db.name} to read secret-family in compartment ${data.oci_identity_compartment.this.name}",
    "Allow dynamic-group ${oci_identity_dynamic_group.db.name} to manage objects in compartment ${data.oci_identity_compartment.this.name} where target.bucket.name='${var.backup_bucket_name}'",
  ]

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "iam"
  }
}
