resource "aws_instance" "host" {
  ami                         = local.ami_id
  instance_type               = local.instance_type
  subnet_id                   = data.aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.host.id]
  iam_instance_profile        = aws_iam_instance_profile.host.name
  associate_public_ip_address = true
  monitoring                  = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
    tags                  = merge(local.tags, { Name = "${local.instance_name}-root" })
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    prefix           = local.prefix
    aws_region       = local.aws_region
    ecr_registry     = local.ecr_registry
    ecr_repo_name    = local.ecr_repo_name
    dd_api_key_param = local.dd_api_key_param
    dd_site          = "datadoghq.com"
  })
  user_data_replace_on_change = true

  tags = { Name = local.instance_name }

  depends_on = [
    aws_iam_role_policy.host,
    aws_iam_role_policy_attachment.host_ssm_core,
    aws_ssm_parameter.dd_api_key,
  ]
}
