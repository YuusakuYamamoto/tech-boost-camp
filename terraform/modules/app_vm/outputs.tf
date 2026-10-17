output "instance_id" {
  value       = oci_core_instance.this.id
  description = "OCID of the application VM."
}

output "private_ip" {
  value       = var.private_ip
  description = "Private IP assigned to the application VM."
}
