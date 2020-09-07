resource "aws_instance" "example" {
  # ...

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Destroy-time provisioner'"
    on_failure = continue 
    //on_failure = fail // Default behaviour
  }
}