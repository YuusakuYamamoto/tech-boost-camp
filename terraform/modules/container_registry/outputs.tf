output "repository_ids" {
  value       = { for k, v in oci_artifacts_container_repository.this : k => v.id }
  description = "Map of repository name to OCID."
}
