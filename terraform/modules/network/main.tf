# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_vcn

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.app_name}-vcn"
  dns_label      = replace(var.app_name, "-", "") # ハイフン不可のため

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}
