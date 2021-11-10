locals {
  ssm_arns = [
    for name, outputs in merge(
      aws_ssm_parameter.params,
      aws_ssm_parameter.secret_log_options,
    ) :
    outputs.arn
  ]

  // Break the SSM param ARNs into var.secret_policy_chunks chunks to avoid 
  // having any single policy over the 6144 character limit
  ssm_chunks = chunklist(
    local.ssm_arns,
    ceil(length(local.ssm_arns) / var.secret_policy_chunks)
  )

  // Combine existing secret_environment variables, fetched secrets from Vault.
  combined_secret_environment = merge(var.secret_environment, {
    for secret_meta in var.vault_secrets :
    secret_meta.env_name => data.vault_generic_secret.vault_secret[secret_meta.env_name].data[secret_meta.secret_key]
  })

  // Combine existing log_secrets variables, with fetched secrets from Vault.
  combined_log_secrets = merge(var.log_secrets, {
    for secret_meta in var.vault_log_secrets :
    secret_meta.name => data.vault_generic_secret.vault_log_secret[secret_meta.name].data[secret_meta.secret_key]
  })

  has_secrets = length(var.secret_environment) + length(var.vault_secrets) + length(var.vault_log_secrets) + length(var.log_secrets) > 0
  always_changing_value = timestamp()
}

resource "aws_ssm_parameter" "params" {
  for_each = local.combined_secret_environment

  description = "Param for the ${each.key} env var in the container: ${var.name}"

  name  = "${var.deploy_env}-${var.ssm_prefix}-${each.key}"
  value = each.value

  type = "SecureString"
  tier = length(each.value) > 4096 ? "Advanced" : "Standard"

  tags = var.tags
}

resource "aws_ssm_parameter" "secret_log_options" {
  for_each = local.combined_log_secrets

  description = "Log option named ${each.key} in the container: ${var.name}"

  name  = "${var.deploy_env}-logOptions-${var.ssm_prefix}-${each.key}"
  value = each.value

  type = "SecureString"
  tier = length(each.value) > 4096 ? "Advanced" : "Standard"

  tags = var.tags
}

data "aws_iam_policy_document" "secret_access_policy_doc" {
  count = local.has_secrets ? var.secret_policy_chunks : 0
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
    ]
    resources = local.ssm_chunks[count.index]
  }
}

data "vault_generic_secret" "vault_secret" {
  for_each = { for secret_meta in var.vault_secrets : secret_meta.env_name => secret_meta }
  # Force the data source to be looked up during the apply step, not the plan step.
  # See: https://github.com/hashicorp/terraform-provider-vault/issues/1221
  path     = trimprefix("${local.always_changing_value}${each.value.path}", local.always_changing_value)
  version  = each.value.secret_version >= 0 ? each.value.secret_version : null
}

data "vault_generic_secret" "vault_log_secret" {
  for_each = { for secret_meta in var.vault_log_secrets : secret_meta.name => secret_meta }
  # Force the data source to be looked up during the apply step, not the plan step.
  # See: https://github.com/hashicorp/terraform-provider-vault/issues/1221
  path     = trimprefix("${local.always_changing_value}${each.value.path}", local.always_changing_value)
  version  = each.value.secret_version >= 0 ? each.value.secret_version : null
}

resource "aws_iam_policy" "secret_access_policy" {
  count       = local.has_secrets ? var.secret_policy_chunks : 0
  name_prefix = "${var.deploy_env}-${var.name}-secret-access-policy"
  description = "Gives access to read ssm env vars"
  policy      = data.aws_iam_policy_document.secret_access_policy_doc[count.index].json
}

module "definition" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "v0.45.2"

  container_name  = var.name
  container_image = var.image

  container_cpu                = var.cpu
  container_memory             = var.memory
  container_memory_reservation = var.memoryReservation

  healthcheck          = var.healthcheck
  essential            = var.essential
  container_depends_on = var.container_depends_on
  volumes_from         = var.volumes_from
  entrypoint           = var.entrypoint
  mount_points         = var.mount_points
  working_directory    = var.working_directory
  command              = var.command

  port_mappings = [
    for port in var.containerPorts :
    {
      containerPort = port
      hostPort      = port
      protocol      = "tcp"
    }
  ]

  log_configuration = var.use_cloudwatch_logs ? {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.aws_region
      "awslogs-group"         = aws_cloudwatch_log_group.log_group[0].name
      "awslogs-stream-prefix" = "ecs--${var.name}"
    }
    secretOptions = []
    } : merge(var.log_configuration, {
      secretOptions = concat(var.extra_log_secret_options, [
        for name, outputs in aws_ssm_parameter.secret_log_options :
        {
          name      = name
          valueFrom = outputs.arn
        }
      ])
  })

  environment = [
    for name in sort(keys(var.environment)) :
    {
      name  = name
      value = var.environment[name]
    }
  ]

  secrets = concat(var.existing_secret_environment, [
    for name, outputs in aws_ssm_parameter.params :
    {
      name      = name
      valueFrom = outputs.arn
    }
  ])

  linux_parameters = var.linux_parameters
  docker_security_options = var.docker_security_options
}

resource "aws_cloudwatch_log_group" "log_group" {
  count = var.use_cloudwatch_logs ? 1 : 0
  name  = "${var.name}-log-group"
  tags  = var.tags
}
