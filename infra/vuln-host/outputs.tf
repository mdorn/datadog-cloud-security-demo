output "instance_id" {
  value = aws_instance.host.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "redeploy_document" {
  value = aws_ssm_document.redeploy.name
}
