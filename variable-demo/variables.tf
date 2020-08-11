variable "region" {
  default = "us-east-2"
}

variable "profile" {
  default = "my-profile"
}

variable "cidrs" {
  type    = list
  default = []
}

variable "amis" {
  type    = map
  default = {}
}