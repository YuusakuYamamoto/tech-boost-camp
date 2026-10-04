variable "compartment_id" {
  type        = string
  description = "OCID of the compartment where load balancer resources will be created."
}

variable "app_name" {
  type        = string
  description = "Application name used as prefix for resource names (e.g., tbcamp)."
}

variable "subnet_id" {
  type        = string
  description = "OCID of the public subnet where the Load Balancer will be placed."
}

variable "nsg_id" {
  type        = string
  description = "OCID of the LB NSG to attach to the Load Balancer and add security rules to."
}

variable "app_nsg_id" {
  type        = string
  description = "OCID of the App NSG (used as destination in the LB egress rule)."
}

variable "frontend_port" {
  type        = number
  description = "Port the Next.js container listens on."
  default     = 3000
}

variable "backend_port" {
  type        = number
  description = "Port the NestJS container listens on."
  default     = 4000
}

variable "api_path_prefix" {
  type        = string
  description = "Path prefix routed to the backend backend set. Everything else goes to the frontend."
  default     = "/api"
}

variable "bandwidth_mbps" {
  type        = number
  description = "Flexible LB bandwidth in Mbps, applied to both minimum and maximum. Always Free allows 10."
  default     = 10
}

variable "use_reserved_ip" {
  type        = bool
  description = "Create and attach a reserved public IP so the address survives LB re-creation. Set false to fall back to an ephemeral IP."
  default     = true
}

# HTTPS リスナーの作成はこの変数で条件化する。証明書の作成元（内部 CA / Let's Encrypt）
# に依存しないよう、OCID を受け取るだけの構造にしている。
variable "certificate_ids" {
  type        = list(string)
  description = "OCIDs of Certificates service certificates for the HTTPS listener. Empty list skips the HTTPS listener."
  default     = []
}
