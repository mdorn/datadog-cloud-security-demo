# Adopt the existing (CloudFormation-created) integration and Agentless scan
# options. The IAM roles and scanner stack remain owned by CloudFormation.
import {
  to = datadog_integration_aws_account.demo
  id = "0554a31e-3967-4055-a0d3-211ed4cbe835"
}

import {
  to = datadog_agentless_scanning_aws_scan_options.demo
  id = "897722680419"
}
