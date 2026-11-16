# Read-only lookup of the demo bucket name from the state of infra/vulnerable.
data "terraform_remote_state" "vulnerable" {
  backend = "s3"
  config = {
    bucket  = "tfstate-mdorn"
    key     = "cspm-remed-demo/vulnerable/terraform.tfstate"
    region  = "us-east-2"
    profile = "default"
  }
}

locals {
  slack_target = "@slack-Datadog-mdorn-demo-public"
  demo_bucket  = data.terraform_remote_state.vulnerable.outputs.bucket_name
  demo_sg_name = "cspm-remed-demo-open-ssh"
}

# Routes by resource (name tag) rather than by severity alone, so incidental
# env:demo findings (VPC endpoints, flow logs, ...) don't reach Slack.
resource "datadog_security_notification_rule" "s3_public" {
  name = "cspm-remed-demo-s3-public"

  selectors {
    trigger_source = "security_findings"
    rule_types     = ["misconfiguration"]
    severities     = ["critical", "high", "medium"]
    query          = "env:demo name:${local.demo_bucket}"
  }

  time_aggregation = 0
  targets          = [local.slack_target]
}

resource "datadog_security_notification_rule" "sg_open_ssh" {
  name = "cspm-remed-demo-sg-open-ssh"

  selectors {
    trigger_source = "security_findings"
    rule_types     = ["misconfiguration"]
    severities     = ["critical", "high", "medium"]
    query          = "env:demo name:${local.demo_sg_name}"
  }

  time_aggregation = 0
  targets          = [local.slack_target]
}

resource "datadog_security_notification_rule" "critical_vulns" {
  name = "cspm-remed-demo-critical-vulns"

  selectors {
    trigger_source = "security_findings"
    rule_types = [
      "container_image_vulnerability",
      "host_vulnerability",
      "application_library_vulnerability",
    ]
    severities = ["critical"]
    query      = "env:demo"
  }

  time_aggregation = 3600
  targets          = [local.slack_target]
}
