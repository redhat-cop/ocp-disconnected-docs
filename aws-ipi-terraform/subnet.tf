data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.isolated_vpc.id
  cidr_block              = "10.2.48.0/20"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.isolated_vpc.id
  cidr_block              = "10.2.64.0/20"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

}

resource "aws_subnet" "private_c" {
  vpc_id                  = aws_vpc.isolated_vpc.id
  cidr_block              = "10.2.80.0/20"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = false
}

resource "aws_subnet" "nat_subnet" {
  vpc_id                  = aws_vpc.isolated_vpc.id
  cidr_block              = "10.2.112.0/20"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.public_vpc.id
  cidr_block              = "10.1.0.0/20"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.public_vpc.id
  cidr_block              = "10.1.16.0/20"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.public_vpc.id
  cidr_block              = "10.1.32.0/20"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true

}