# =============================================================================
# Network Module - VCN, Subnets, Gateways, Route Tables, NSGs
# =============================================================================

# --- Data Sources ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/core_services
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# --- VCN ---

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

# --- Default Security List（ルールを空にして NSG に統一） ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_default_security_list
resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id
  display_name               = "${var.app_name}-default-security-list"

  # ルールを定義しない = デフォルトルールを全て削除
  # ファイアウォールは NSG で管理する方針

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}

# --- Gateways ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_internet_gateway
resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.app_name}-igw"
  enabled        = true

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_service_gateway
resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.app_name}-sgw"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}

# --- Route Tables ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_route_table
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.app_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
    description       = "Internet access via Internet Gateway"
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_route_table
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.app_name}-private-rt"

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
    description       = "Oracle Services access via Service Gateway"
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}

# --- Subnets ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_subnet
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${var.app_name}-public-subnet"
  dns_label                  = "pub"
  prohibit_internet_ingress  = false
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_vcn.this.default_security_list_id]

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_subnet
resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${var.app_name}-private-subnet"
  dns_label                  = "priv"
  prohibit_internet_ingress  = true
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_vcn.this.default_security_list_id]

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}

# --- Network Security Groups（箱のみ、ルールは後続ステップで追加） ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group
resource "oci_core_network_security_group" "app" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.app_name}-app-nsg"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group
resource "oci_core_network_security_group" "db" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.app_name}-db-nsg"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "network"
  }
}