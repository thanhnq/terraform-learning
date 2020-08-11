terraform {
  backend "remote" {
    organization = "thakel"

    workspaces {
      name = "thakel-ws"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_instance" "example" {
  ami           = "ami-b374d5a5"
  instance_type = "t2.micro"
}