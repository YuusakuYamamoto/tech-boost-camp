output "container_instance_id" {
  value       = oci_container_instances_container_instance.this.id
  description = "OCID of the Container Instance."
}

output "private_ip" {
  value       = var.private_ip
  description = "Private IP assigned to the Container Instance."
}
