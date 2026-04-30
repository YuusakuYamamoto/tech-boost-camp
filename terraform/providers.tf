provider "oci" {
  region = var.region
  # 明示しないと DEFAULT プロファイル(管理者権限)を自動選択してしまうため、最小権限の TBCAMP_TERRAFORM プロファイルを明示的に指定する。
  config_file_profile = "TBCAMP_TERRAFORM"
}
