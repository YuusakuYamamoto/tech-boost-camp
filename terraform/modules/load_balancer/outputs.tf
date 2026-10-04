output "load_balancer_id" {
  value       = oci_load_balancer_load_balancer.this.id
  description = "OCID of the Load Balancer."
}

output "public_ip" {
  value       = var.use_reserved_ip ? oci_core_public_ip.lb[0].ip_address : oci_load_balancer_load_balancer.this.ip_address_details[0].ip_address
  description = "Public IP address of the Load Balancer. Register this as the A record for the domain."
}

output "frontend_backend_set_name" {
  value       = oci_load_balancer_backend_set.frontend.name
  description = "Name of the frontend backend set (register Next.js backends here in Step 10)."
}

output "backend_backend_set_name" {
  value       = oci_load_balancer_backend_set.backend.name
  description = "Name of the backend backend set (register NestJS backends here in Step 10)."
}
