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

resource "aws_vpc_security_group_ingress_rule" "icmp_echo_reply" {
  description       = "Allow ICMP Echo Reply (type 0)"
  security_group_id = aws_security_group.consumer.id
  from_port         = 0
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    {
      Name = "ICMP Echo Reply"
    },
    local.default_module_tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "icmp_destination_unreachable" {
  description       = "Allow ICMP Destination Unreachable (type 3)"
  security_group_id = aws_security_group.consumer.id
  from_port         = 3
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    {
      Name = "ICMP Destination Unreachable"
    },
    local.default_module_tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "icmp_echo_request" {
  description       = "Allow ICMP Echo Request (type 8)"
  security_group_id = aws_security_group.consumer.id
  from_port         = 8
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    {
      Name = "ICMP Echo Request"
    },
    local.default_module_tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "icmp_time_exceeded" {
  description       = "Allow ICMP Time Exceeded (type 11)"
  security_group_id = aws_security_group.consumer.id
  from_port         = 11
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge(
    {
      Name = "ICMP Time Exceeded"
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
