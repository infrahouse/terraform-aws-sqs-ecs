output "asg_arn" {
  description = "ARN of the created autoscaling group."
  value       = aws_autoscaling_group.consumer.arn
}
