locals {
  app_name = "tbcamp"
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
}
