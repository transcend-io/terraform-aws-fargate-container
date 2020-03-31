locals {
  all_secrets = merge(
    var.secret_environment,
    var.secret_environment,
  )
  has_secrets = length(local.all_secrets) > 0
}

/**
 * We want to have a plan appear anytime the definition will be updated on a
 * run of `terraform plan`.
 *
 * As the primary purpose of this module is to create json output and not create a resource,
 * the bulk of the work does not show up in plans. So we use a dummy resource here to make changes
 * to the json document appear in the plan.
 */
resource null_resource dummy {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    container_definition = module.definition.json
    what_is_this   = <<EOF
    You may be wondering why you're seeing some resource named `null_resource.dummy` with a plan
    after updating this module. Well no fear, this is just done to let you know that you need
    to run an `atlantis apply` on the CI system to change the output of this module.
    EOF
  }
}

resource "aws_ssm_parameter" "params" {
  for_each = var.secret_environment

  description = "Param for the ${each.key} env var in the container: ${var.name}"

  name  = "${var.deploy_env}-${var.ssm_prefix}-${each.key}"
  value = each.value

  type = "SecureString"
  tier = length(each.value) > 4096 ? "Advanced" : "Standard"

  tags = var.tags
}

resource "aws_ssm_parameter" "secret_log_options" {
  for_each = var.log_secrets

  description = "Log option named ${each.key} in the container: ${var.name}"

  name  = "${var.deploy_env}-logOptions-${var.ssm_prefix}-${each.key}"
  value = each.value

  type = "SecureString"
  tier = length(each.value) > 4096 ? "Advanced" : "Standard"

  tags = var.tags
}

data "aws_iam_policy_document" "secret_access_policy_doc" {
  count = local.has_secrets ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      for name, outputs in merge(
        aws_ssm_parameter.params,
        aws_ssm_parameter.secret_log_options,
      ) :
      outputs.arn
    ]
  }
}

resource "aws_iam_policy" "secret_access_policy" {
  count       = local.has_secrets ? 1 : 0
  name_prefix = "${var.deploy_env}-${var.name}-secret-access-policy"
  description = "Gives access to read ssm env vars"
  policy      = data.aws_iam_policy_document.secret_access_policy_doc[0].json
}

module "definition" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "v0.21.0"

  container_name  = var.name
  container_image = var.image

  container_cpu    = var.cpu
  container_memory = var.memory

  healthcheck = var.healthcheck

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
      secretOptions = [
        for name, outputs in aws_ssm_parameter.secret_log_options :
        {
          name      = name
          valueFrom = outputs.arn
        }
      ]
  })

  environment = [
    for name in sort(keys(var.environment)) :
    {
      name  = name
      value = var.environment[name]
    }
  ]

  secrets = [
    for name, outputs in aws_ssm_parameter.params :
    {
      name      = name
      valueFrom = outputs.arn
    }
  ]
}

resource "aws_cloudwatch_log_group" "log_group" {
  count = var.use_cloudwatch_logs ? 1 : 0
  name  = "${var.name}-log-group"
  tags  = var.tags
}
