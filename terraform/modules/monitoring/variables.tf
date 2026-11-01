variable "tenancy_id" {
  type        = string
  description = "OCID of the tenancy. Budgets are always created in the root compartment."
}

variable "compartment_id" {
  type        = string
  description = "OCID of the compartment that the budget targets and that holds the topic and alarms (tbcamp)."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names and freeform tags (e.g., tbcamp)."
}

variable "notification_email" {
  type        = string
  description = "Email address that receives budget alerts and alarm notifications."
  sensitive   = true
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget as a whole number, in the currency of the tenancy's rate card (JPY for this tenancy)."
}

variable "budget_alert_thresholds" {
  type        = list(number)
  description = "Percentages of the budget at which an actual-spend alert fires (ADR-0017)."
  default     = [50, 80, 100]
}
