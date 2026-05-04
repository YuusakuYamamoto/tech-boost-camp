output "app_dynamic_group_id" {
  value       = oci_identity_dynamic_group.app.id
  description = "OCID of the Dynamic Group for Container Instances."
}

output "db_dynamic_group_id" {
  value       = oci_identity_dynamic_group.db.id
  description = "OCID of the Dynamic Group for Compute Instances."
}

output "runtime_policy_id" {
  value       = oci_identity_policy.runtime.id
  description = "OCID of the runtime IAM policy."
}
