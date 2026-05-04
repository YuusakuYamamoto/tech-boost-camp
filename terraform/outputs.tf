output "vcn_id" {
  value       = module.network.vcn_id
  description = "OCID of the created VCN."
}

output "public_subnet_id" {
  value       = module.network.public_subnet_id
  description = "OCID of the public subnet."
}

output "private_subnet_id" {
  value       = module.network.private_subnet_id
  description = "OCID of the private subnet."
}

output "app_security_group_id" {
  value       = module.network.app_security_group_id
  description = "OCID of the NSG for Container Instances (app)."
}

output "db_security_group_id" {
  value       = module.network.db_security_group_id
  description = "OCID of the NSG for PostgreSQL VM (db)."
}
