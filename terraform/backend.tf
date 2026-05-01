# OCI native backend for Terraform state management.
# Docs: https://developer.hashicorp.com/terraform/language/backend/oci
#
# Required attributes (bucket, namespace) cannot be set via env vars.
# - bucket: hardcoded here (not sensitive, fixed for this project)
# - namespace: provided via backend.hcl (gitignored, env-specific)
#
# Notes:
#   - The backend block does NOT support variable or local references.
#     `region` here intentionally duplicates var.region used by the provider.
#     Keep both in sync if the deployment region changes.
#   - State file is stored at: <bucket>/<key>
#     => terraform-state/tbcamp/terraform.tfstate
#   - Lock file is auto-managed at: tbcamp/terraform.tfstate.lock
#   - Authentication uses the TBCAMP_TERRAFORM profile from ~/.oci/config
#     to keep parity with provider-side auth (least privilege).
terraform {
  backend "oci" {
    bucket = "terraform-state"
    key    = "tbcamp/terraform.tfstate"
    region = "ap-tokyo-1"
    # namespace, config_file_profile はローカル/CI で異なるため partial configuration
    # ローカル: backend.hcl で指定
    # CI: namespace は -backend-config 引数、認証は OCI_CLI_* 環境変数
  }
}
