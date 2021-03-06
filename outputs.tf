output json {
  value       = module.definition.json_map_encoded_list
  description = "JSON string representing the container definition"
}

output json_map {
  value       = module.definition.json_map_encoded
  description = "Object representing the container definition"
}

output secrets_policy_arns {
  value = [
    for resource, outputs in aws_iam_policy.secret_access_policy :
    outputs.arn
  ]
  description = "Amazon Resource Name of an IAM Policies granting access to read the SSM Parameters created in this module. Empty if no secrets are present"
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
