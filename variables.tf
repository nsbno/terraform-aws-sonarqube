variable "name_prefix" {
  description = "A prefix used for naming resources."
}

variable "snapshot_identifier" {
  description = "The identifier of the snapshot to create the database from - if left empty a new db will be created"
  default     = ""
}

variable "sonarqube_aws_env_img" {
  description = "Which grafana-aws-env docker image to use"
  default     = "vydev/sonarqube-aws-env:latest"
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 7200. Only valid for services configured to use load balancers."
  type        = number
  default     = 360
}

variable "vpc_cidr_block" {
  description = "The cidr block for the entire VPC"
  type        = string
  default     = "10.9.0.0/16"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

variable "private_subnet_count" {
  description = "Number of private subnets in the VPC (min 2 for RDS)"
  type        = number
  default     = 2
}

variable "task_definition_cpu" {
  description = "Amount of CPU to reserve for the task."
  type        = number
  default     = 512
}

variable "task_definition_memory" {
  description = "The soft limit (in MiB) of memory to reserve for the container."
  type        = number
  default     = 2048
}

variable "hosted_zone_name" {
  description = "The name of the hosted zone in Route53 to create the DNS entries in"
  type        = string
}

variable "parameters_key_arn" {
  description = "The ARN of the kms key used to encrypt the parameters"
}