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
