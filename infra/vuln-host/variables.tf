variable "dd_api_key" {
  description = "Datadog API key for the host Agent. Export with: export TF_VAR_dd_api_key=$DD_API_KEY. Used only as a write-only value; never stored in plan or state."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "dd_api_key_version" {
  description = "Increment to push a new value of dd_api_key to SSM (key rotation)."
  type        = number
  default     = 1
}
