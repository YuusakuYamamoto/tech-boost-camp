# =============================================================================
# Bastion Module - OCI Bastion + SSH ingress on target NSGs
# =============================================================================

# --- Bastion ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/bastion_bastion
resource "oci_bastion_bastion" "this" {
  bastion_type                 = "standard"
  compartment_id               = var.compartment_id
  target_subnet_id             = var.target_subnet_id
  name                         = var.bastion_name
  client_cidr_block_allow_list = var.client_cidr_block_allow_list

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "bastion"
  }
}

# --- NSG ルール ---

# 送信元が Bastion 作成後に決まる値（private_endpoint_ip_address）のため、network
# モジュールに置くと network → bastion → network と参照が往復する。ここに置けば
# 一方向で済む。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule
resource "oci_core_network_security_group_security_rule" "bastion_ssh" {
  for_each = var.target_nsg_ids

  network_security_group_id = each.value
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "${oci_bastion_bastion.this.private_endpoint_ip_address}/32"
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  description               = "SSH from bastion private endpoint (${each.key})"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}
