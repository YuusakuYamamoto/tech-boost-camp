# =============================================================================
# IAM Module - Dynamic Groups + Runtime Policy
# =============================================================================

# --- 定義済みタグ（インスタンスの役割） ---

# Dynamic Group のマッチングルールはフリーフォームタグを参照できない。定義済みタグ
# のみが `tag.<名前空間>.<キー>.value` の形で使える。
# 名前空間は廃止（retire）してからでないと削除できないため、名前は変更しない前提で扱う。
# Docs: https://docs.oracle.com/en-us/iaas/Content/Identity/dynamicgroups/Writing_Matching_Rules_to_Define_Dynamic_Groups.htm
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_tag_namespace
resource "oci_identity_tag_namespace" "this" {
  compartment_id = var.compartment_id
  name           = var.app_name
  description    = "Defined tags for ${var.app_name} resources"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "iam"
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_tag
resource "oci_identity_tag" "role" {
  tag_namespace_id = oci_identity_tag_namespace.this.id
  name             = "role"
  description      = "Role of the instance (db / app). Used in dynamic group matching rules."

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "iam"
  }
}

# --- Dynamic Groups（テナンシーレベルで作成 — OCI の仕様） ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_dynamic_group
resource "oci_identity_dynamic_group" "app" {
  compartment_id = var.tenancy_id
  name           = "${var.app_name}-app-instances"
  description    = "Application Compute Instances in ${var.app_name} compartment for Instance Principal auth"
  # Container Instance 用（resource.type = 'computecontainerinstance'）から、
  # 定義済みタグで絞る形に変更した（ADR-0001 / ADR-0022）。
  matching_rule = "All {instance.compartment.id = '${var.compartment_id}', tag.${oci_identity_tag_namespace.this.name}.${oci_identity_tag.role.name}.value = 'app'}"

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
  description    = "PostgreSQL Compute Instances in ${var.app_name} compartment for Instance Principal auth"
  # instance.compartment.id は Compute Instance 専用の属性で、対象種別を含意するため
  # resource.type の指定は不要。resource.compartment.id では実際にマッチしなかった。
  # compartment 内の全 Compute Instance に一致してしまうため、定義済みタグで絞る
  # （ADR-0022）。
  matching_rule = "All {instance.compartment.id = '${var.compartment_id}', tag.${oci_identity_tag_namespace.this.name}.${oci_identity_tag.role.name}.value = 'db'}"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "iam"
  }
}

# Certificates サービスの CA はリソースプリンシパルとして KMS の鍵に署名を依頼する。
# そのための Dynamic Group（Step 9c の CA 作成に先行して必要）。
# Docs: https://docs.oracle.com/en-us/iaas/Content/certificates/managing-certificate-authorities.htm
resource "oci_identity_dynamic_group" "cert_authorities" {
  compartment_id = var.tenancy_id
  name           = "${var.app_name}-cert-authorities"
  description    = "Certificate Authorities for Resource Principal auth"
  # resource.compartment.id での絞り込みは、db 動的グループで実際にマッチしなかった
  # 前例があるため採らない。公式ドキュメントが示す形のまま使う。
  # テナンシ内の CA は本プロジェクトのもののみのため、絞り込みなしで実害はない。
  matching_rule = "resource.type = 'certificateauthority'"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "iam"
  }
}

# --- Runtime Policy（tbcamp compartment に配置） ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_policy
resource "oci_identity_policy" "runtime" {
  compartment_id = var.compartment_id
  name           = "${var.app_name}-runtime-policy"
  description    = "Runtime permissions for ${var.app_name} Container Instances, VMs and Certificate Authorities"

  # OCIR からの pull はリソースプリンシパル + IAM ポリシーで解決する。同一テナンシーの
  # Container Registry では image pull secret（Vault 連携）は使わない。
  # Docs: https://docs.oracle.com/en-us/iaas/Content/container-instances/vault-secrets-image-authorization.htm
  # Docs: https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registrypolicyrepoaccess.htm
  #
  # db と app で権限を分けている（ADR-0022）。バックアップバケットへの書き込みは db のみ。
  statements = [
    # --- db（PostgreSQL VM） ---
    "Allow dynamic-group ${oci_identity_dynamic_group.db.name} to read buckets in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.db.name} to read secret-family in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.db.name} to manage objects in compartment id ${var.compartment_id} where target.bucket.name='${var.backup_bucket_name}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.db.name} to read objects in compartment id ${var.compartment_id} where target.bucket.name='${var.config_bucket_name}'",

    # --- app（アプリケーション VM） ---
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to read secret-family in compartment id ${var.compartment_id}",
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to read objects in compartment id ${var.compartment_id} where target.bucket.name='${var.config_bucket_name}'",
    "Allow dynamic-group ${oci_identity_dynamic_group.app.name} to read repos in compartment id ${var.compartment_id}",

    # --- 証明書 CA ---
    "Allow dynamic-group ${oci_identity_dynamic_group.cert_authorities.name} to use keys in compartment id ${var.compartment_id}",
  ]

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "iam"
  }
}
