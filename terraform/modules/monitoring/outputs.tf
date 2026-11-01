output "alarms_topic_id" {
  value       = oci_ons_notification_topic.alarms.id
  description = "OCID of the Notifications topic used as the alarm destination."
}

output "budget_id" {
  value       = oci_budget_budget.this.id
  description = "OCID of the budget. Created in the root compartment, not in tbcamp."
}
