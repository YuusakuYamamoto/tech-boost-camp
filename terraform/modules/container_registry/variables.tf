variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where OCIR repositories will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used for tagging (e.g., tbcamp)."
}

variable "repository_names" {
  type        = list(string)
  description = "List of OCIR repository names to create (e.g., [\"tbcamp-frontend\", \"tbcamp-backend\"])."
}
