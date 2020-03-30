output json {
  value       = module.definition.json
  description = "JSON string representing the container definition"
}

output json_map {
  value       = module.definition.json_map
  description = "Object representing the container definition"
}

output secrets_policy_arn {
  value       = aws_iam_policy.secret_access_policy[0].arn
  description = "Amazon Resource Name of an IAM Policy granting access to read the SSM Parameters created in this module"
}

output container_name {
  value       = var.name
  description = "The name of the container"
}

output container_ports {
  value       = var.containerPorts
  description = <<EOF
  Port mappings allow containers to access ports on the host container instance to send or receive traffic.
  Each port number given will be mapped from the container to the host over the tcp protocol.
  EOF
}
