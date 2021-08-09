resource "aws_instance" "public" {
  ami                         = "ami-0cca63ccd9a87f1b2"
  availability_zone           = data.aws_availability_zones.available.names[0]
  ebs_optimized               = true
  instance_type               = "t3.small"
  monitoring                  = false
  key_name                    = "ec2_key"
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address = true
  source_dest_check           = true

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 120
    delete_on_termination = true
  }

}
/*
resource "aws_instance" "private" {
  ami                         = "ami-0cca63ccd9a87f1b2"
  availability_zone           = data.aws_availability_zones.available.names[0]
  ebs_optimized               = true
  instance_type               = "t3.small"
  monitoring                  = false
  key_name                    = aws_key_pair.bastion_key.key_name
  subnet_id                   = aws_subnet.private_a.id
  associate_public_ip_address = false
  source_dest_check           = true

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 120
    delete_on_termination = true
  }
}*/
