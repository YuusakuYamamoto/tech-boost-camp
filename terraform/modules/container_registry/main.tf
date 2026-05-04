# =============================================================================
# Container Registry Module - OCIR Repositories
# =============================================================================

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/artifacts_container_repository
resource "oci_artifacts_container_repository" "this" {
  for_each = toset(var.repository_names)

  compartment_id = var.compartment_id
  display_name   = each.value
  is_public      = false
  is_immutable   = false

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "container-registry"
  }
}
