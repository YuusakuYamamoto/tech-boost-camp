# =============================================================================
# Container App Module - Container Instance + LB Backend 登録
# =============================================================================

# --- Data Sources ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/identity_availability_domains
data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_id
}

# --- Container Instance ---

# containers / shape / shape_config / vnics はいずれも非 Updatable で、変更すると
# インスタンスの破棄と再作成になる。image_url もこれに含まれるため、タグ変数を
# 書き換えて apply するだけで入れ替えが成立する（ADR-0011）。
#
# private_ip を固定しているため create_before_destroy は付けない。新旧が同じ IP を
# 同時に保持できず衝突するため。置き換え中は LB が 502 を返す。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/container_instances_container_instance
resource "oci_container_instances_container_instance" "this" {
  compartment_id      = var.compartment_id
  display_name        = "${var.app_name}-${var.role}"
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpu_count
    memory_in_gbs = var.memory_in_gbs
  }

  vnics {
    subnet_id             = var.subnet_id
    nsg_ids               = [var.nsg_id]
    private_ip            = var.private_ip
    is_public_ip_assigned = false
    display_name          = "${var.app_name}-${var.role}-vnic"
  }

  containers {
    display_name = "${var.app_name}-${var.role}"
    image_url    = var.image_url

    # リソースプリンシパルを有効にする。OCIR からの pull（Step 10b）と、
    # エントリポイントスクリプトが Vault から Secret を取得する方式
    # （ADR-0015）の前提。ドキュメントに既定値の記載がないため明示する。
    is_resource_principal_disabled = false

    environment_variables = merge(
      var.environment_variables,
      { for k, v in var.vault_secret_ocids : "${k}_SECRET_OCID" => v },
    )
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = var.role
  }
}

# --- LB Backend 登録 ---

# ip_address / port は非 Updatable。private_ip を固定しているため、Container
# Instance が置き換わってもこのリソースには差分が出ない。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_backend
resource "oci_load_balancer_backend" "this" {
  load_balancer_id = var.load_balancer_id
  backendset_name  = var.backend_set_name
  ip_address       = var.private_ip
  port             = var.port
}

# --- App NSG ルール ---

# LB からの転送とヘルスチェックの両方がこの経路を通る。LB NSG 側の egress は
# Step 9 で設定済み（load_balancer モジュールの lb_app_egress）。
# app NSG の egress は network モジュールが持つ（役割ごとに分かれないため）。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule
resource "oci_core_network_security_group_security_rule" "lb_ingress" {
  network_security_group_id = var.nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow traffic and health checks from the LB NSG to ${var.role}"

  source      = var.lb_nsg_id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = var.port
      max = var.port
    }
  }
}
