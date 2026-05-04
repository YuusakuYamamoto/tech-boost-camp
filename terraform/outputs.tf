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

output "vault_id" {
  value       = module.vault.vault_id
  description = "OCID of the created Vault."
}

output "key_id" {
  value       = module.vault.key_id
  description = "OCID of the master encryption key."
}

output "secret_ids" {
  value       = module.vault.secret_ids
  description = "Map of secret name to OCID."
}

output "pg_backups_bucket_name" {
  value       = module.object_storage.bucket_name
  description = "Name of the pg-backups bucket."
}

output "app_dynamic_group_id" {
  value       = module.iam.app_dynamic_group_id
  description = "OCID of the Dynamic Group for Container Instances."
}

output "db_dynamic_group_id" {
  value       = module.iam.db_dynamic_group_id
  description = "OCID of the Dynamic Group for Compute Instances."
}

output "container_repository_ids" {
  value       = module.container_registry.repository_ids
  description = "Map of OCIR repository name to OCID."
}

output "postgres_vm_private_ip" {
  value       = module.postgres_vm.private_ip
  description = "Private IP address of the PostgreSQL VM."
}

output "postgres_vm_instance_id" {
  value       = module.postgres_vm.instance_id
  description = "OCID of the PostgreSQL VM."
}
