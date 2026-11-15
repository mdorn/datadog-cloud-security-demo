# Credentials come only from DD_API_KEY / DD_APP_KEY env vars.
# Site defaults to datadoghq.com (US1).
provider "datadog" {
  api_url = "https://api.datadoghq.com/"
}
