# =============================================================================
# App VM Module - Compute Instance + Docker Compose + LB Backend 登録
# =============================================================================

# --- Data Sources ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/identity_availability_domains
data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_id
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/core_images
data "oci_core_images" "ol9_arm" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.A1.Flex"
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# --- cloud-init ---

locals {
  bootstrap_script = templatefile("${path.module}/scripts/bootstrap-app.sh", {
    namespace             = var.namespace
    config_bucket         = var.config_bucket_name
    db_password_secret_id = var.db_password_secret_id
    session_secret_id     = var.session_secret_id
    db_host               = var.db_host
  })

  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    bootstrap_b64 = base64encode(local.bootstrap_script)
    app_name      = var.app_name
  })
}

# --- Compute Instance ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance
resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_id
  display_name        = "${var.app_name}-app-vm"
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ocpu_count
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol9_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  # private_ip を固定する。LB Backend の ip_address は非 Updatable なため、IP を
  # 固定すると Backend が VM のライフサイクルから切り離され、VM を作り直しても
  # Backend に差分が出ない。
  create_vnic_details {
    subnet_id        = var.subnet_id
    nsg_ids          = [var.nsg_id]
    private_ip       = var.private_ip
    assign_public_ip = false
    display_name     = "${var.app_name}-app-vnic"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.cloud_init)
  }

  # Bastion の Managed SSH セッションに必要（ADR-0023）。agent_config は更新可能な
  # 属性で、VM の再作成は伴わない。
  # Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance
  agent_config {
    plugins_config {
      name          = "Bastion"
      desired_state = "ENABLED"
    }
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "app-vm"
  }

  # Dynamic Group のマッチングルールが参照する（ADR-0022）。
  defined_tags = var.defined_tags

  depends_on = [oci_objectstorage_object.compose]

  # data.oci_core_images は常に最新を返すため、Oracle Linux の月次更新のたびに
  # source_id のドリフトが発生する。source_id の変更はブートボリュームの置き換えを
  # 引き起こし、ブートボリューム上の構成が失われる。postgres_vm と同じ対処。
  #
  # defined_tags はマップ全体を置き換える属性のため、config に書いていない
  # Oracle-Tags（OCI が自動付与する CreatedBy / CreatedOn）が削除対象になる。
  # 値は作成時に決まるもので config に書けないため、キー単位で無視する。
  lifecycle {
    ignore_changes = [
      source_details[0].source_id,
      defined_tags["Oracle-Tags.CreatedBy"],
      defined_tags["Oracle-Tags.CreatedOn"],
    ]
  }
}

# --- Config Object ---

# docker-compose.yml は cloud-init に埋め込まない。metadata が ForceNew 属性のため、
# compose を変更するたびに VM が replace されてしまう。Object Storage に置き、
# 起動時に Instance Principal で取得する（postgres_vm と同じ）。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/objectstorage_object
resource "oci_objectstorage_object" "compose" {
  namespace    = var.namespace
  bucket       = var.config_bucket_name
  object       = "app/docker-compose.yml"
  content      = file("${path.module}/files/docker-compose.yml")
  content_type = "application/yaml"
}

# --- LB Backend 登録 ---

# ip_address / port は非 Updatable。private_ip を固定しているため、VM が置き換わっても
# これらのリソースには差分が出ない。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_backend
resource "oci_load_balancer_backend" "frontend" {
  load_balancer_id = var.load_balancer_id
  backendset_name  = var.frontend_backend_set_name
  ip_address       = var.private_ip
  port             = var.frontend_port
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_backend
resource "oci_load_balancer_backend" "backend" {
  load_balancer_id = var.load_balancer_id
  backendset_name  = var.backend_backend_set_name
  ip_address       = var.private_ip
  port             = var.backend_port
}

# --- App NSG ルール ---

# LB からの転送とヘルスチェックの両方がこの経路を通る。LB NSG 側の egress は Step 9 で
# 設定済み（load_balancer モジュールの lb_app_egress）。app NSG の egress は network
# モジュールが持つ（ポートで分かれないため）。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule
resource "oci_core_network_security_group_security_rule" "lb_ingress_frontend" {
  network_security_group_id = var.nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow traffic and health checks from the LB NSG to the frontend"

  source      = var.lb_nsg_id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = var.frontend_port
      max = var.frontend_port
    }
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule
resource "oci_core_network_security_group_security_rule" "lb_ingress_backend" {
  network_security_group_id = var.nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow traffic and health checks from the LB NSG to the backend"

  source      = var.lb_nsg_id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = var.backend_port
      max = var.backend_port
    }
  }
}
