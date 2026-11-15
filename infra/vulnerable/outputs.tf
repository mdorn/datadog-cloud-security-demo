output "bucket_name" {
  value = aws_s3_bucket.public_assets.bucket
}

output "security_group_id" {
  value = aws_security_group.open_ssh.id
}

output "iam_user_name" {
  value = aws_iam_user.overprivileged.name
}
