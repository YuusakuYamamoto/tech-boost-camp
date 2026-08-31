# =============================================================================
# Object Storage Module - Backup Bucket
# =============================================================================

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/objectstorage_namespace
data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_id
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/objectstorage_bucket
resource "oci_objectstorage_bucket" "pg_backups" {
  compartment_id = var.compartment_id
  name           = "${var.app_name}-pg-backups"
  namespace      = data.oci_objectstorage_namespace.this.namespace
  access_type    = "NoPublicAccess"
  versioning     = "Disabled"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "object-storage"
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/objectstorage_bucket
resource "oci_objectstorage_bucket" "config" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "${var.app_name}-config"
  access_type    = "NoPublicAccess"
  versioning     = "Enabled" // composeファイルのバージョン管理のために有効化

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "config"
  }
}
