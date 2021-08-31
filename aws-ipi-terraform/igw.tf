resource "aws_internet_gateway" "public_gw" {
  vpc_id = aws_vpc.public_vpc.id
}

resource "aws_internet_gateway" "isolated_gw" {
  vpc_id = aws_vpc.isolated_vpc.id
}

resource "aws_eip" "nat" {

}

resource "aws_nat_gateway" "isolated_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.nat_subnet.id

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.isolated_gw]
}



resource "aws_default_route_table" "public_route" {
  default_route_table_id = aws_vpc.public_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_gw.id
  }

  route {
    cidr_block                = aws_vpc.isolated_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }
}


resource "aws_default_route_table" "isolated_route" {
  default_route_table_id = aws_vpc.isolated_vpc.default_route_table_id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.isolated_nat.id
  }


  route {
    cidr_block                = aws_vpc.public_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }
}

resource "aws_route_table" "nat" {
  vpc_id = aws_vpc.isolated_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.isolated_gw.id
  }
}

resource "aws_route_table_association" "nat" {
  subnet_id      = aws_subnet.nat_subnet.id
  route_table_id = aws_route_table.nat.id
}

