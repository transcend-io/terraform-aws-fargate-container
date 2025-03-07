variable name {
  type        = string
  description = <<EOF
  The name of a container. Up to 255 letters (uppercase and lowercase), numbers, hyphens,
  and underscores are allowed. If you are linking multiple containers together in a task
  definition, the name of one container can be entered in the links of another container
  to connect the containers.
  EOF
}

variable image {
  type        = string
  description = <<EOF
  The image used to start a container. This string is passed directly to the Docker daemon.
  Images in the Docker Hub registry are available by default. You can also specify other
  repositories with either repository-url/image:tag or repository-url/image@digest. Up to 255
  letters (uppercase and lowercase), numbers, hyphens, underscores, colons, periods, forward
  slashes, and number signs are allowed.
  EOF
}

variable cpu {
  type        = number
  default     = 512
  description = <<EOF
  The number of cpu units the Amazon ECS container agent will reserve for the container.
  EOF
}

variable memory {
  type        = number
  default     = 1024
  description = <<EOF
  The amount (in MiB) of memory to present to the container. If your container attempts to
  exceed the memory specified here, the container is killed. The total amount of memory reserved
  for all containers within a task must be lower than the task memory value, if one is specified.
  EOF
}

variable memoryReservation {
  type        = number
  default     = 512
  description = <<EOF
  The amount of memory (in MiB) to reserve for the container. If container needs to exceed this threshold,
  it can do so up to the set container_memory hard limit"
  EOF
}

variable containerPorts {
  type        = list(number)
  default     = []
  description = <<EOF
  Port mappings allow containers to access ports on the host container instance to send or receive traffic.
  Each port number given will be mapped from the container to the host over the tcp protocol.
  EOF
}

variable portNames {
  type        = map(string)
  default     = {}
  description = "A map of port numbers to their respective names for service discovery"
}

variable environment {
  type        = map(string)
  default     = {}
  description = <<EOF
  The non-secret environment variables to pass to a container.

  Usage would be something like:
  environment = {
    SOME_ENV_VAR = "123"
    SOME_OTHER_ENV_VAR = "nice"
  }
  EOF
}

variable secret_environment {
  type        = map(string)
  default     = {}
  description = <<EOF
  The secret environment variables to pass to a container.

  Usage would be something like:
  environment = {
    SOME_ENV_VAR = "123"
    SOME_OTHER_ENV_VAR = "nice"
  }

  These will be made into SSM SecureString parameters, which
  will be dynamically fetched and set as env vars on boot.
  EOF
}

variable existing_secret_environment {
  type = list(object({
    name      = string
    valueFrom = string
  }))
  description = "A way for you to use existing SSM params as env vars"
  default     = []
}

variable secret_policy_chunks {
  type        = number
  default     = 1
  description = <<EOF
  By default, a single IAM policy is created for accessing SSM params.

  In the case that you have many, many params, you may hit the Managed Policy
  Character Limit of 6144 characters (whitespace not included): https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-limits.html

  In this case, increasing this value will make additional policies that split the environment map into var.secret_policy_chunks IAM
  Policies, all still attached to the ECS Task Role.
  EOF
}

variable tags {
  type        = map(string)
  description = "Tags to apply to all resources that support them"
}

variable ssm_prefix {
  type        = string
  description = "Prefix to put in front of all ssm parameter keys"
  default     = "ssm"
}

variable deploy_env {
  type        = string
  description = "The environment resources are to be created in. Usually dev, staging, or prod"
}

variable aws_region {
  type        = string
  description = "The AWS region to create resources in."
  default     = "eu-west-1"
}

variable use_cloudwatch_logs {
  type        = bool
  description = "If true, a cloudwatch group will be created and written to."
  default     = true
}

# https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html
variable log_configuration {
  type = object({
    logDriver = string
    options   = map(string)
  })
  default = {
    logDriver = "awslogs"
    options   = {}
  }
  description = <<EOF
  Log configuration options to send to a custom log driver for the container.
  For more details, see https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html

  This parameter is ignored if use_cloudwatch_logs is true, and a log group will be automatically
  written to.

  Use log_secrets to set extra options here that should be secret, such as API keys for third party loggers.
  EOF
}

variable log_secrets {
  type        = map(string)
  default     = {}
  description = "Used to add extra options to log_configuration.options that should be secret, such as third party API keys"
}

variable extra_log_secret_options {
  type = list(object({
    name      = string
    valueFrom = string
  }))
  description = "A way for you to use existing SSM params in logs"
  default     = []
}

# https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_HealthCheck.html
variable healthcheck {
  type = object({
    command     = list(string)
    retries     = number
    timeout     = number
    interval    = number
    startPeriod = number
  })
  description = "A map containing command (string), timeout, interval (duration in seconds), retries (1-10, number of times to retry before marking container unhealthy), and startPeriod (0-300, optional grace period to wait, in seconds, before failed healthchecks count toward retries)"
  default     = null
}

variable essential {
  type        = bool
  default     = true
  description = "Determines whether all other containers in a task are stopped, if this container fails or stops for any reason."
}

variable "container_depends_on" {
  type = list(object({
    containerName = string
    condition     = string
  }))
  description = "The dependencies defined for container startup and shutdown. A container can contain multiple dependencies. When a dependency is defined for container startup, for container shutdown it is reversed. The condition can be one of START, COMPLETE, SUCCESS or HEALTHY"
  default     = null
}

variable "volumes_from" {
  type = list(object({
    sourceContainer = string
    readOnly        = bool
  }))
  description = "A list of VolumesFrom maps which contain \"sourceContainer\" (name of the container that has the volumes to mount) and \"readOnly\" (whether the container can write to the volume)"
  default     = []
}

variable "mount_points" {
  type        = list
  description = "Container mount points. This is a list of maps, where each map should contain a `containerPath` and `sourceVolume`. The `readOnly` key is optional."
  default     = []
}

variable "entrypoint" {
  type        = list(string)
  description = "The entry point that is passed to the container"
  default     = null
}

variable "command" {
  type        = list(string)
  description = "The command that is passed to the container"
  default     = null
}

# https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LinuxParameters.html
variable "linux_parameters" {
  type = object({
    capabilities = object({
      add  = list(string)
      drop = list(string)
    })
    devices = list(object({
      containerPath = string
      hostPath      = string
      permissions   = list(string)
    }))
    initProcessEnabled = bool
    maxSwap            = number
    sharedMemorySize   = number
    swappiness         = number
    tmpfs = list(object({
      containerPath = string
      mountOptions  = list(string)
      size          = number
    }))
  })
  description = "Linux-specific modifications that are applied to the container, such as Linux kernel capabilities. For more details, see https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LinuxParameters.html"
  default     = null
}

variable "docker_security_options" {
  type        = list(string)
  description = "A list of strings to provide custom labels for SELinux and AppArmor multi-level security systems."
  default     = null
}

variable "working_directory" {
  type        = string
  description = "The working directory to run commands inside the container"
  default     = null
}

variable "vault_secrets" {
  type = list(object({
    env_name       = string,
    path           = string,
    secret_key     = string,
    secret_version = number
  }))
  description = "List of secrets to fetch from Vault"
  default     = []
}

variable "vault_log_secrets" {
  type        = list(object({
    name           = string,
    path           = string,
    secret_key     = string,
    secret_version = number
  }))
  default     = []
  description = <<EOF
Used to add extra options to log_configuration.options that should be secret, such as third party API keys, fetched from Vault.
EOF
}
