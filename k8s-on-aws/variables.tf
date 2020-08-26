variable "region" {
  default = "us-east-1"
}

variable "profile" {
  default = "default"
}

variable "amis" {
  type    = map
  default = {}
}

variable "private_az" {
  default = "us-east-1a"
}

variable "public_az" {
  default = "us-east-1b"
}

variable "instance_private_key" {

}

variable "instance_public_key" {

}

variable "instance_user" {
  default = "ec2-user"
}