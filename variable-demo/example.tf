provider "aws" {
  profile = var.profile
  region  = var.region
}

resource "aws_instance" "example" {
  ami           = var.amis[var.region]
  instance_type = "t2.micro"
}

output "ip" {
  value = aws_instance.example.public_ip
}