# =============================================================================
# Certificates Module - Internal Root CA and TLS certificate
# =============================================================================
#
# Step 9c 時点では内部 CA を使う。ブラウザ警告は出るが、HTTPS リスナーの
# 構成そのものは検証できる。Step 12 で Let's Encrypt に差し替える。
# load_balancer の certificate_ids は OCID を受け取るだけの設計なので、
# そのときに差し替えるのはこのモジュールの中身だけで済む。
#
# CRL は設定しない。内部 CA は Step 12 で役目を終えるため失効リストを
# 運用する意味がなく、設定すると Object Storage バケットと追加の IAM
# （CA 用 Dynamic Group に manage objects、管理者側に read buckets）が要る。

# --- Root CA ---

# CA はリソースプリンシパルとして KMS の鍵に署名を依頼するため、
# iam モジュールの tbcamp-cert-authorities 動的グループとポリシーが前提。
# 権限不足は 403 ではなく 404 で返る点に注意。
#
# path_length_constraint は設定しない。中間 CA を発行できなくなる制約で、
# 後から更新できない。学習目的で中間 CA を試す余地を残す。
#
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/certificates_management_certificate_authority
resource "oci_certificates_management_certificate_authority" "root" {
  compartment_id = var.compartment_id
  name           = "${var.app_name}-internal-ca-${var.name_suffix}"
  description    = "Internal root CA for ${var.domain_name}. Temporary until Let's Encrypt (Step 12)."
  kms_key_id     = var.kms_key_id

  certificate_authority_config {
    config_type       = "ROOT_CA_GENERATED_INTERNALLY"
    signing_algorithm = "SHA256_WITH_RSA"

    # リーフ証明書と CN が被ると検証時に紛らわしいため、CA 側は別名にする。
    subject {
      common_name  = "${var.app_name} internal root CA"
      organization = var.subject_organization
      country      = var.subject_country
    }

    # ルート CA には発行元が存在しないため、有効期限を明示する必要がある。
    validity {
      time_of_validity_not_after = var.ca_validity_not_after
    }
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "certificates"
  }
}

# --- Leaf Certificate ---

# validity を省略すると発行元 CA の有効期間が使われるため明示する。
# 証明書が更新されても OCID は変わらず、バージョン番号が増える仕組み。
# LB が新しいバージョンに自動追従するかは apply 後の確認項目。
#
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/certificates_management_certificate
resource "oci_certificates_management_certificate" "app" {
  compartment_id = var.compartment_id
  name           = "${var.app_name}-tls-${var.name_suffix}"
  description    = "TLS certificate for ${var.domain_name}"

  certificate_config {
    config_type                     = "ISSUED_BY_INTERNAL_CA"
    issuer_certificate_authority_id = oci_certificates_management_certificate_authority.root.id
    # LB での TLS 終端専用。clientAuth は不要なので TLS_SERVER_OR_CLIENT より狭い方を選ぶ。
    certificate_profile_type = "TLS_SERVER"
    key_algorithm            = "RSA2048"
    signature_algorithm      = "SHA256_WITH_RSA"

    subject {
      common_name  = var.domain_name
      organization = var.subject_organization
      country      = var.subject_country
    }

    # CN と同じ値でも SAN に入れておく。現代のブラウザは CN を見ず
    # SAN のみで検証するため、SAN がないと内部 CA を信頼させても
    # 名前不一致で弾かれる。
    subject_alternative_names {
      type  = "DNS"
      value = var.domain_name
    }

    validity {
      time_of_validity_not_after = var.certificate_validity_not_after
    }
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "certificates"
  }
}
