terraform {
  backend "local" {
    path = "relative/path/to/terraform.tfstate"
  }
}

//data source configuration
data "terraform_remote_state" "example" {
  backend = "local"

  config = {
    path = "${path.module}/../../terraform.tfstate"
  }
}