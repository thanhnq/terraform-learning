// Using a single workspace
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "example_corp"

    workspaces {
      name = "my-app-prod"
    }
  }
}

// Using multiple workspaces
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "company"

    workspaces {
      prefix = "my-app-"
    }
  }
}