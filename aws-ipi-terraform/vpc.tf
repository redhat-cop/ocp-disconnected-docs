resource "aws_vpc" "public_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
}

resource "aws_vpc" "isolated_vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
}

resource "aws_vpc_peering_connection" "peer" {
  peer_vpc_id = aws_vpc.public_vpc.id
  vpc_id      = aws_vpc.isolated_vpc.id
  auto_accept = true
}