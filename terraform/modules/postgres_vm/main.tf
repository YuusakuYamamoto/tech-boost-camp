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
  cloud_init = <<-CLOUD_INIT
    #cloud-config
    package_update: true
    package_upgrade: false

    packages:
      - yum-utils

    write_files:
      - path: /home/opc/setup-disk.sh
        permissions: '0755'
        owner: root:root
        content: |
          #!/bin/bash
          # Block volume のフォーマットとマウント
          # terraform apply 後、ボリュームがアタッチされてから実行する
          set -euo pipefail
          DEVICE="/dev/oracleoci/oraclevdb"
          MOUNT_POINT="/data"

          if ! blkid "$DEVICE" > /dev/null 2>&1; then
            echo "Formatting $DEVICE as xfs..."
            mkfs.xfs "$DEVICE"
          else
            echo "$DEVICE is already formatted, skipping."
          fi

          mkdir -p "$MOUNT_POINT"
          if ! grep -q "oraclevdb" /etc/fstab; then
            echo "$DEVICE $MOUNT_POINT xfs defaults,_netdev,nofail 0 2" >> /etc/fstab
          fi
          mount -a
          mkdir -p "$MOUNT_POINT/postgres"
          chown -R opc:opc "$MOUNT_POINT/postgres"
          echo "Done. Block volume mounted at $MOUNT_POINT"

    runcmd:
      - yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
      - dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      - systemctl start docker
      - systemctl enable docker
      - usermod -aG docker opc
  CLOUD_INIT
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
