output "vault_id" {
  value       = oci_kms_vault.this.id
  description = "OCID of the created Vault."
}

output "key_id" {
  value       = oci_kms_key.this.id
  description = "OCID of the master encryption key."
}

output "secret_ids" {
  value       = { for k, v in oci_vault_secret.this : k => v.id }
  description = "Map of secret name to OCID (e.g., {\"db-password\" = \"ocid1.vaultsecret...\"})."
}
