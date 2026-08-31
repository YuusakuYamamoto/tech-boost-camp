# =============================================================================
# PostgreSQL VM Module - Compute Instance + Block Volume
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
  bootstrap_script = templatefile("${path.module}/scripts/bootstrap-postgres.sh", {
    namespace     = var.namespace
    config_bucket = var.config_bucket_name
    secret_id     = var.db_password_secret_id
  })

  backup_script = templatefile("${path.module}/scripts/backup-postgres.sh", {
    namespace     = var.namespace
    backup_bucket = var.backup_bucket_name
  })

  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    setup_disk_b64 = base64encode(file("${path.module}/scripts/setup-disk.sh")) // Terraform変数を含まないため file() で読み込み
    bootstrap_b64  = base64encode(local.bootstrap_script)
    backup_b64     = base64encode(local.backup_script)
  })
}

# --- Compute Instance ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance
resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_id
  display_name        = "${var.app_name}-postgres-vm"
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol9_arm.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    nsg_ids          = [var.db_nsg_id]
    assign_public_ip = false
    display_name     = "${var.app_name}-postgres-vnic"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.cloud_init)
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "postgres-vm"
  }

  depends_on = [oci_objectstorage_object.compose]
}

# --- Block Volume（PostgreSQL データ用） ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_volume
resource "oci_core_volume" "data" {
  compartment_id      = var.compartment_id
  display_name        = "${var.app_name}-pg-data"
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
  size_in_gbs         = 50

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "postgres-vm"
  }
}

# --- Volume Attachment ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_volume_attachment
resource "oci_core_volume_attachment" "data" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.this.id
  volume_id       = oci_core_volume.data.id
  device          = "/dev/oracleoci/oraclevdb"
  display_name    = "${var.app_name}-pg-data-attachment"
  is_read_only    = false
}

# --- DB NSG ルール ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule

# SSH: VCN 内からのアクセスを許可（OCI Cloud Shell / Bastion 経由）
resource "oci_core_network_security_group_security_rule" "db_ssh_ingress" {
  network_security_group_id = var.db_nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow SSH from within VCN"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# PostgreSQL: App NSG からのアクセスを許可
resource "oci_core_network_security_group_security_rule" "db_postgres_ingress" {
  network_security_group_id = var.db_nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow PostgreSQL from App NSG"

  source      = var.app_nsg_id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }
}

# Egress: すべてのアウトバウンド通信を許可（Oracle Services + Docker pull 用）
resource "oci_core_network_security_group_security_rule" "db_all_egress" {
  network_security_group_id = var.db_nsg_id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Allow all outbound traffic"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
}

# --- Config Object ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/objectstorage_object
resource "oci_objectstorage_object" "compose" {
  namespace    = var.namespace
  bucket       = var.config_bucket_name
  object       = "postgres/docker-compose.yml"
  content      = file("${path.module}/files/docker-compose.yml")
  content_type = "application/yaml"
}
