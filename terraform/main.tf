locals {
  app_name    = "tbcamp"
  domain_name = "y12u.com"

  # CA 用鍵 / CA / 証明書はいずれもスケジュール削除で、削除猶予中は同名で
  # 作り直せない。作り直すときはこの値をインクリメントして 3 つまとめて
  # 世代を揃える。
  name_suffix = "01"
}

module "network" {
  source = "./modules/network"

  compartment_id      = var.compartment_id
  app_name            = local.app_name
  vcn_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
}

module "vault" {
  source = "./modules/vault"

  compartment_id      = var.compartment_id
  app_name            = local.app_name
  key_protection_mode = "SOFTWARE"
  name_suffix         = local.name_suffix
  secret_names = [
    "db-password",
    "google-oauth-client-secret",
    "session-secret",
  ]
}

module "object_storage" {
  source = "./modules/object_storage"

  compartment_id = var.compartment_id
  app_name       = local.app_name
}

module "iam" {
  source = "./modules/iam"

  tenancy_id         = var.tenancy_id
  compartment_id     = var.compartment_id
  app_name           = local.app_name
  backup_bucket_name = module.object_storage.bucket_name
  config_bucket_name = module.object_storage.config_bucket_name
}

module "container_registry" {
  source = "./modules/container_registry"

  compartment_id = var.compartment_id
  app_name       = local.app_name
  repository_names = [
    "${local.app_name}-frontend",
    "${local.app_name}-backend",
  ]
}

module "postgres_vm" {
  source = "./modules/postgres_vm"

  compartment_id        = var.compartment_id
  app_name              = local.app_name
  subnet_id             = module.network.private_subnet_id
  db_nsg_id             = module.network.db_security_group_id
  app_nsg_id            = module.network.app_security_group_id
  vcn_cidr              = "10.0.0.0/16"
  ssh_public_key        = var.ssh_public_key
  namespace             = module.object_storage.namespace
  config_bucket_name    = module.object_storage.config_bucket_name
  backup_bucket_name    = module.object_storage.bucket_name
  db_password_secret_id = module.vault.secret_ids["db-password"]
}

module "certificates" {
  source = "./modules/certificates"

  compartment_id = var.compartment_id
  app_name       = local.app_name
  domain_name    = local.domain_name
  kms_key_id     = module.vault.ca_key_id
  name_suffix    = local.name_suffix
}

module "load_balancer" {
  source = "./modules/load_balancer"

  compartment_id = var.compartment_id
  app_name       = local.app_name
  subnet_id      = module.network.public_subnet_id
  nsg_id         = module.network.lb_security_group_id
  app_nsg_id     = module.network.app_security_group_id

  # 要素の値は apply 時まで未確定だが、リストの長さは plan 時に確定するため
  # HTTPS リスナーと redirect rule set の count は解決できる。
  certificate_ids = [module.certificates.certificate_id]
}
