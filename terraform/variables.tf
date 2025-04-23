  variable "grafana_auth" {
    description = "Grafana authentication string (username:password)"
    type        = string
    sensitive   = true
  }

  variable "postgres_password" {
    description = "PostgreSQL password"
    type        = string
    default     = "mypassword"
  }