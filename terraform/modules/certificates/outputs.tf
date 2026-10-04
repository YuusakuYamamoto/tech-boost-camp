output "certificate_id" {
  value       = oci_certificates_management_certificate.app.id
  description = "OCID of the TLS certificate. Pass this to the load balancer's certificate_ids."
}

output "certificate_authority_id" {
  value       = oci_certificates_management_certificate_authority.root.id
  description = "OCID of the internal root CA."
}

output "certificate_authority_name" {
  value       = oci_certificates_management_certificate_authority.root.name
  description = "Name of the internal root CA (includes the suffix)."
}
