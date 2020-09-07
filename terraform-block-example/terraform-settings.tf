terraform {
  //require version for terraform itself
  required_version = ">= 0.12.0"

  // require version and source for providers
  required_providers {
    aws = {
      version = ">= 2.7.0"
      source  = "hashicorp/aws"
    }
  }

  //opt-in experiment named example
  experiments = [example]
}