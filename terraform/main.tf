# CI test: trigger plan workflow against deployment/infra/main

locals {
  app_name = "tbcamp"
}

module "network" {
  source = "./modules/network"

  compartment_id = var.compartment_id
  app_name       = local.app_name
}
