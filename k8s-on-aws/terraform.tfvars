region = "ap-southeast-1"

profile = "default"

private_az = "ap-southeast-1a"

public_az = "ap-southeast-1b"

amis = {
  "us-east-1"      = "ami-06cf02a98a61f9f5e"
  "ap-southeast-1" = "ami-056251cdd6fd1c8eb"
}

instance_private_key = "~/.ssh/k8s_on_aws"

instance_public_key = "~/.ssh/k8s_on_aws.pub"

instance_user = "centos"