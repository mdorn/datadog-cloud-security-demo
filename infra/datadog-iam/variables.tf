variable "datadog_app_key_id" {
  description = "ID (not the secret value) of the application key in DD_APP_KEY. Export with: export TF_VAR_datadog_app_key_id=$(scripts/dd-app-key-id.sh)"
  type        = string
}
