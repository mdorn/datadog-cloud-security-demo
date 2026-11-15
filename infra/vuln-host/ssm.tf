resource "aws_ssm_parameter" "dd_api_key" {
  name             = local.dd_api_key_param
  description      = "Datadog API key read by the demo host Agent (secret backend aws.ssm)"
  type             = "SecureString"
  value_wo         = var.dd_api_key
  value_wo_version = var.dd_api_key_version
}

resource "aws_ssm_document" "redeploy" {
  name            = local.redeploy_document
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Deploy a cspm-remed-demo-app image tag on the demo host and restart the app container"
    parameters = {
      ImageTag = {
        type           = "String"
        description    = "12-character git SHA image tag in ${local.ecr_repo_name}"
        allowedPattern = "^[0-9a-f]{12}$"
      }
    }
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "redeploy"
      inputs = {
        timeoutSeconds = "600"
        runCommand = [
          "set -eu",
          "install -d -m 0755 /etc/${local.prefix}",
          "echo '{{ ImageTag }}' > /etc/${local.prefix}/image-tag",
          "systemctl restart ${local.prefix}-app.service",
          "sleep 5",
          "docker inspect demo-app | python3 -c 'import json,sys; c=json.load(sys.stdin)[0]; print(\"running\", c[\"Config\"][\"Image\"], c[\"Image\"], c[\"State\"][\"Status\"])'",
        ]
      }
    }]
  })
}
