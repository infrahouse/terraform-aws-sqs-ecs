locals {
  service_name = "sqs-test-${random_string.suffix.result}"
}

locals {
  # The test consumer: cloud-init writes it to the host, and the task mounts
  # the host's directory.
  test_consumer_image   = "public.ecr.aws/docker/library/python:3.13.12-slim"
  test_consumer_dir     = "/opt/sqs-ecs-test-consumer"
  test_consumer_command = ["python3", "${local.test_consumer_dir}/consumer.py"]
  test_consumer_files = [
    {
      path        = "${local.test_consumer_dir}/consumer.py"
      content     = file("${path.module}/files/consumer.py")
      permissions = "0644"
    }
  ]
  test_consumer_volumes = {
    test-consumer : {
      host_path      = local.test_consumer_dir
      container_path = local.test_consumer_dir
    }
  }
}
