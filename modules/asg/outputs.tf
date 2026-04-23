output "asg_arn" {
  description = "ARN of the created autoscaling group."
  value       = aws_autoscaling_group.consumer.arn
}

output "asg_name" {
  description = "Name of the created autoscaling group."
  value       = aws_autoscaling_group.consumer.name
}

# These outputs are needed to inject dependencies into the ECS module
output "security_group_inbound_rule" {
  value = aws_vpc_security_group_ingress_rule.icmp_echo_request.id
}
output "security_group_outbound_rule" {
  value = aws_vpc_security_group_egress_rule.default.id
}
