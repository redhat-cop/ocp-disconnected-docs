/*
output "private_instance" {
  value = aws_instance.private.private_dns
}
*/
output "public_instance" {
  value = aws_instance.public.public_ip
}

output "subnet_a_cidr" {
  value = aws_subnet.private_a.cidr_block
}

output "subnet_b_cidr" {
  value = aws_subnet.private_b.cidr_block
}

output "subnet_c_cidr" {
  value = aws_subnet.private_c.cidr_block
}

output "zone_a" {
    value = data.aws_availability_zones.available.names[0]
}

output "zone_b" {
    value = data.aws_availability_zones.available.names[1]
}

output "zone_c" {
    value = data.aws_availability_zones.available.names[2]
}


output "subnet_a" {
    value = aws_subnet.private_a.id
}

output "subnet_b" {
    value = aws_subnet.private_b.id
}

output "subnet_c" {
    value = aws_subnet.private_c.id
}
