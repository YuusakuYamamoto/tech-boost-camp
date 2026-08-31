output "bucket_name" {
  value       = oci_objectstorage_bucket.pg_backups.name
  description = "Name of the pg-backups bucket."
}

output "namespace" {
  value       = data.oci_objectstorage_namespace.this.namespace
  description = "Object Storage namespace of the tenancy."
}

output "config_bucket_name" {
  value       = oci_objectstorage_bucket.config.name
  description = "Name of the bucket that stores application config files."
}