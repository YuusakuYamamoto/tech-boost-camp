output "bastion_id" {
  value       = oci_bastion_bastion.this.id
  description = "OCID of the Bastion."
}

output "bastion_private_endpoint_ip" {
  value       = oci_bastion_bastion.this.private_endpoint_ip_address
  description = "IP address of the Bastion private endpoint."
}
