provider "aws" {
  profile = var.profile
  region  = var.region
}

resource "aws_vpc" "k8s_on_aws" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "k8s_vpc"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.k8s_on_aws.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.private_az
  tags = {
    Name = "k8s_vpc_private_subnet_01"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.k8s_on_aws.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.public_az
  tags = {
    Name = "k8s_vpc_public_subnet_01"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_on_aws.id
  tags = {
    Name = "k8s_vpc_igw"
  }
}

resource "aws_eip" "public_ip_for_natgw" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "k8s_vpc_eip_01"
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.public_ip_for_natgw.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "k8s_vpc_natgw_01"
  }
}

resource "aws_default_route_table" "default_route_table_k8s_vpc" {
  default_route_table_id = aws_vpc.k8s_on_aws.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "k8s_vpc_default_rt"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.k8s_on_aws.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = {
    Name = "k8s_vpc_private_rt_01"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_key_pair" "k8s_on_aws" {
  key_name   = "k8s_on_aws"
  public_key = file(var.instance_public_key)
  tags = {
    Name = "k8s_on_aws_key_pair"
  }
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.k8s_on_aws.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "k8s_vpc_bastion_sg"
  }
}

resource "aws_security_group" "k8s_private_sg" {
  vpc_id = aws_vpc.k8s_on_aws.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "k8s_vpc_k8s_private_sg"
  }
}

resource "aws_instance" "bastion" {
  key_name                    = aws_key_pair.k8s_on_aws.key_name
  ami                         = var.amis[var.region]
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  availability_zone           = var.public_az
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  connection {
    type        = "ssh"
    user        = var.instance_user
    private_key = file(var.instance_private_key)
    host        = self.public_ip
  }

  provisioner "file" {
    source      = var.instance_private_key
    destination = var.instance_private_key
  }

  provisioner "file" {
    source      = "ansible_hosts"
    destination = "~/hosts"
  }

  provisioner "remote-exec" {
    inline = ["chmod 400 ${var.instance_private_key}", "sudo mkdir /etc/ansible && sudo mv ~/hosts /etc/ansible/", "sudo yum install epel-release -y && sudo yum install ansible -y"]
  }
  tags = {
    Name = "bastion"
  }
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

resource "aws_network_interface" "master01_private" {
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.k8s_private_sg.id]
  tags = {
    Name = "master01_private"
  }
}

resource "aws_network_interface" "master01_vip" {
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.k8s_private_sg.id]
  tags = {
    Name = "master01_vip"
  }
}

resource "aws_instance" "master01" {
  key_name          = aws_key_pair.k8s_on_aws.key_name
  ami               = var.amis[var.region]
  instance_type     = "t2.medium"
  availability_zone = var.private_az
  network_interface {
    network_interface_id = aws_network_interface.master01_private.id
    device_index         = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.master01_vip.id
    device_index         = 1
  }
  connection {
    type         = "ssh"
    bastion_host = aws_instance.bastion.public_ip
    user         = var.instance_user
    private_key  = file(var.instance_private_key)
    host         = aws_network_interface.master01_private.private_ip
  }

  provisioner "file" {
    source      = "ifcfg-eth1"
    destination = "~/ifcfg-eth1"
  }

  provisioner "file" {
    content     = "default via 10.0.1.1 dev eth0 table 1000"
    destination = "~/route-eth0"
  }

  provisioner "file" {
    content     = "from ${aws_network_interface.master01_private.private_ip}/32 table 1000 priority 1000"
    destination = "~/rule-eth0"
  }

  provisioner "file" {
    content     = "default via 10.0.1.1 dev eth1 table 1001"
    destination = "~/route-eth1"
  }

  provisioner "file" {
    content     = "from ${aws_network_interface.master01_vip.private_ip}/32 table 1001 priority 1001"
    destination = "~/rule-eth1"
  }

  provisioner "remote-exec" {
    inline = ["echo 'GATEWAYDEV=eth0' | sudo tee -a /etc/sysconfig/network", "sudo mv ~/ifcfg-eth1 ~/route-eth0 ~/route-eth1 ~/rule-eth0 ~/rule-eth1 /etc/sysconfig/network-scripts/", "sudo systemctl restart network"]
  }
  tags = {
    Name = "master01"
  }
}

output "master01_private_ip" {
  value = aws_network_interface.master01_private.private_ip
}

output "master01_vip_ip" {
  value = aws_network_interface.master01_vip.private_ip
}

resource "aws_network_interface" "master02_private" {
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.k8s_private_sg.id]
  tags = {
    Name = "master02_private"
  }
}

resource "aws_network_interface" "master02_vip" {
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.k8s_private_sg.id]
  tags = {
    Name = "master02_vip"
  }
}

resource "aws_instance" "master02" {
  key_name          = aws_key_pair.k8s_on_aws.key_name
  ami               = var.amis[var.region]
  instance_type     = "t2.medium"
  availability_zone = var.private_az
  network_interface {
    network_interface_id = aws_network_interface.master02_private.id
    device_index         = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.master02_vip.id
    device_index         = 1
  }
  connection {
    type         = "ssh"
    bastion_host = aws_instance.bastion.public_ip
    user         = var.instance_user
    private_key  = file(var.instance_private_key)
    host         = aws_network_interface.master02_private.private_ip
  }

  provisioner "file" {
    source      = "ifcfg-eth1"
    destination = "~/ifcfg-eth1"
  }

  provisioner "file" {
    content     = "default via 10.0.1.1 dev eth0 table 1000"
    destination = "~/route-eth0"
  }

  provisioner "file" {
    content     = "from ${aws_network_interface.master02_private.private_ip}/32 table 1000 priority 1000"
    destination = "~/rule-eth0"
  }

  provisioner "file" {
    content     = "default via 10.0.1.1 dev eth1 table 1001"
    destination = "~/route-eth1"
  }

  provisioner "file" {
    content     = "from ${aws_network_interface.master02_vip.private_ip}/32 table 1001 priority 1001"
    destination = "~/rule-eth1"
  }

  provisioner "remote-exec" {
    inline = ["echo 'GATEWAYDEV=eth0' | sudo tee -a /etc/sysconfig/network", "sudo mv ~/ifcfg-eth1 ~/route-eth0 ~/route-eth1 ~/rule-eth0 ~/rule-eth1 /etc/sysconfig/network-scripts/", "sudo systemctl restart network"]
  }
  tags = {
    Name = "master02"
  }
}

output "master02_private_ip" {
  value = aws_network_interface.master02_private.private_ip
}

output "master02_vip_ip" {
  value = aws_network_interface.master02_vip.private_ip
}

resource "aws_instance" "worker01" {
  key_name                    = aws_key_pair.k8s_on_aws.key_name
  ami                         = var.amis[var.region]
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.k8s_private_sg.id]
  availability_zone           = var.private_az
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  tags = {
    Name = "worker01"
  }
}

output "worker01_private_ip" {
  value = aws_instance.worker01.private_ip
}

resource "aws_instance" "worker02" {
  key_name                    = aws_key_pair.k8s_on_aws.key_name
  ami                         = var.amis[var.region]
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.k8s_private_sg.id]
  availability_zone           = var.private_az
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  tags = {
    Name = "worker02"
  }
}

output "worker02_private_ip" {
  value = aws_instance.worker02.private_ip
}

resource "aws_instance" "worker03" {
  key_name                    = aws_key_pair.k8s_on_aws.key_name
  ami                         = var.amis[var.region]
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.k8s_private_sg.id]
  availability_zone           = var.private_az
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  tags = {
    Name = "worker03"
  }
}

output "worker03_private_ip" {
  value = aws_instance.worker03.private_ip
}

resource "aws_route53_zone" "private_zone" {
  name = "int.easycredit.vn"
  vpc {
    vpc_id = aws_vpc.k8s_on_aws.id
  }
}

resource "aws_route53_record" "k8scluster" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "k8scluster.int.easycredit.vn"
  type    = "A"
  ttl     = "300"
  records = [aws_network_interface.master01_vip.private_ip]
}

resource "aws_route53_record" "master01" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "master01.int.easycredit.vn"
  type    = "A"
  ttl     = "300"
  records = [aws_network_interface.master01_private.private_ip]
}

resource "aws_route53_record" "master02" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "master02.int.easycredit.vn"
  type    = "A"
  ttl     = "300"
  records = [aws_network_interface.master02_private.private_ip]
}

resource "aws_route53_record" "worker01" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "worker01.int.easycredit.vn"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.worker01.private_ip]
}

resource "aws_route53_record" "worker02" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "worker02.int.easycredit.vn"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.worker02.private_ip]
}

resource "aws_route53_record" "worker03" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "worker03.int.easycredit.vn"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.worker03.private_ip]
}