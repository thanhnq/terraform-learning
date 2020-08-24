region = "us-east-1"

profile = "default"

private_az = "us-east-1a"

public_az = "us-east-1b"

amis = {
  "us-east-1"      = "ami-01ca03df4a6012157"
  "ap-southeast-1" = "ami-0bfb8f6cdedb56577"
}

instance_private_key = "~/.ssh/k8s_on_aws.key"

instance_public_key = "~/.ssh/k8s_on_aws.pub"

instance_user = "centos"