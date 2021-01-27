output "alb_dns_name" {
  value       = aws_lb.terraform-lb.dns_name
  description = "The domain name of the load balancer"
}

# output the asg name for the schedule of auto scaling

output "asg_name" {
  value = aws_autoscaling_group.terraform-asg.name
  description = "The name of Auto Scaling Group"
}

# outout for the security group of rules for inbound and outbound

output "alb_security_group_id" {
  value = aws_security_group.alb.id
  description = "The ID of the security group attached to the LB"
}