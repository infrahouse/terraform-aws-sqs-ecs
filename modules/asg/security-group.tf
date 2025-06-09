resource "aws_security_group" "consumer" {
  vpc_id      = data.aws_subnet.selected.vpc_id
  name_prefix = "${var.service_name}-consumer-"
  description = "Manage consumer traffic"
  tags = merge(
    {
      Name : "consumer"
    },
    local.default_module_tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "icmp" {
  description       = "Allow all ICMP traffic"
  security_group_id = aws_security_group.consumer.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    {
      Name = "ICMP traffic"
    },
    local.default_module_tags
  )
}

resource "aws_vpc_security_group_egress_rule" "default" {
  description       = "Allow all traffic"
  security_group_id = aws_security_group.consumer.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    {
      Name = "Outgoing traffic"
    },
    local.default_module_tags
  )
}
