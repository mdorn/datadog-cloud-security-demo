output "workflow_role_arn" {
  value = aws_iam_role.workflow.arn
}

output "workflow_connection_id" {
  value = datadog_action_connection.aws.id
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
