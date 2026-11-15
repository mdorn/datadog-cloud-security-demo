output "vpc_id" {
  value = aws_vpc.demo.id
}

output "vpc_arn" {
  value = aws_vpc.demo.arn
}

output "subnet_id" {
  value = aws_subnet.public_a.id
}
