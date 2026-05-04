output "vcn_id" {
  value       = oci_core_vcn.this.id
  description = "OCID of the created VCN."
}

output "public_subnet_id" {
  value       = oci_core_subnet.public.id
  description = "OCID of the public subnet."
}

output "private_subnet_id" {
  value       = oci_core_subnet.private.id
  description = "OCID of the private subnet."
}

output "app_security_group_id" {
  value       = oci_core_network_security_group.app.id
  description = "OCID of the NSG for Container Instances (app)."
}

output "db_security_group_id" {
  value       = oci_core_network_security_group.db.id
  description = "OCID of the NSG for PostgreSQL VM (db)."
}
