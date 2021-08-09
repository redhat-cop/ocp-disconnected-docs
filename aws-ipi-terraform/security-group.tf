
data "aws_ip_ranges" "usgov" {
  regions  = ["us-gov-east-1", "us-gov-west-1"]
  services = ["amazon", "ec2", "route53"]
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.isolated_vpc.id

  egress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = data.aws_ip_ranges.usgov.cidr_blocks
  }

  ingress {
    from_port   = "0"
    to_port     = "65535"
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.isolated_vpc.cidr_block]
  }

  egress {
    from_port   = "0"
    to_port     = "65535"
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.isolated_vpc.cidr_block] 
  }

  ingress {
    from_port   = "0"
    to_port     = "65535"
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.public_vpc.cidr_block]
  }

  egress {
    from_port   = "0"
    to_port     = "65535"
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.public_vpc.cidr_block] 
  }

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }


}

resource "aws_default_security_group" "public_default" {
  vpc_id = aws_vpc.public_vpc.id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}