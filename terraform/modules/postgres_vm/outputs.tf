output "instance_id" {
  value       = oci_core_instance.this.id
  description = "OCID of the PostgreSQL VM."
}

output "private_ip" {
  value       = oci_core_instance.this.private_ip
  description = "Private IP address of the PostgreSQL VM."
}

output "volume_id" {
  value       = oci_core_volume.data.id
  description = "OCID of the Block Volume for PostgreSQL data."
}
