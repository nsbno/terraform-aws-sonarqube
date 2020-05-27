data "aws_availability_zones" "main" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  public_cidr_blocks = [for k, v in data.aws_availability_zones.main.names :
  cidrsubnet(var.vpc_cidr_block, 4, k)]
  private_cidr_blocks = [for k, v in chunklist(data.aws_availability_zones.main.zone_ids, var.private_subnet_count)[0] :
  cidrsubnet(var.vpc_cidr_block, 4, k + length(data.aws_availability_zones.main.names))]
}

module "vpc" {
  source               = "github.com/nsbno/terraform-aws-vpc?ref=ec7f57f"
  name_prefix          = var.name_prefix
  cidr_block           = var.vpc_cidr_block
  public_subnet_cidrs  = local.public_cidr_blocks
  private_subnet_cidrs = local.private_cidr_blocks
  create_nat_gateways  = true
  enable_dns_hostnames = true
  tags                 = var.tags
}

module "sonarqube_rds" {
  source              = "github.com/nsbno/terraform-aws-rds-instance?ref=7e38055"
  name_prefix         = var.name_prefix
  multi_az            = false
  port                = "5432"
  engine              = "postgres"
  instance_type       = "db.t3.small"
  allocated_storage   = "10"
  password            = data.aws_ssm_parameter.sonarqube-rds-password.value
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  username            = data.aws_ssm_parameter.sonarqube-rds-username.value
  tags                = var.tags
  skip_final_snapshot = false
  snapshot_identifier = var.snapshot_identifier
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.name_prefix}-cluster"
}

module "alb" {
  source      = "github.com/nsbno/terraform-aws-loadbalancer?ref=a8cf4b8"
  name_prefix = var.name_prefix
  subnet_ids  = module.vpc.public_subnet_ids
  type        = "application"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = module.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = module.certificate.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    target_group_arn = module.sonarqube_service.target_group_arn
    type             = "forward"
  }
}

module "sonarqube_service" {
  source     = "github.com/nsbno/terraform-aws-ecs-fargate?ref=03df23f"
  cluster_id = aws_ecs_cluster.cluster.id
  health_check = {
    port    = "traffic-port"
    path    = "/api/system/status"
    matcher = "200"
  }
  lb_arn                            = module.alb.arn
  name_prefix                       = var.name_prefix
  private_subnet_ids                = module.vpc.private_subnet_ids
  task_container_image              = var.sonarqube_aws_env_img
  task_container_port               = 9000
  task_container_protocol           = "HTTP"
  vpc_id                            = module.vpc.vpc_id
  task_definition_cpu               = var.task_definition_cpu
  task_definition_memory            = var.task_definition_memory
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  task_container_ulimits = [
    {
      name : "nofile",
      softLimit : 65535,
      hardLimit : 65535
    }
  ]
  task_container_environment_count = 12
  task_container_environment = {
    "AWS_REGION"                     = data.aws_region.current.name
    "SONARQUBE_JDBC_USERNAME"        = "ssm://${data.aws_ssm_parameter.sonarqube-rds-username.name}"
    "SONARQUBE_JDBC_PASSWORD"        = "ssm://${data.aws_ssm_parameter.sonarqube-rds-password.name}"
    "SONARQUBE_JDBC_URL"             = "ssm://${aws_ssm_parameter.sonarqube-rds-url.name}"
    "SONARQUBE_BASE_URL"             = "ssm://${aws_ssm_parameter.sonarqube-base-url.name}"
    "SONARQUBE_GITHUB_AUTH_ENABLED"  = "ssm://${data.aws_ssm_parameter.sonarqube-github-auth-enabled.name}"
    "SONARQUBE_GITHUB_CLIENT_ID"     = "ssm://${data.aws_ssm_parameter.sonarqube-github-client-id.name}"
    "SONARQUBE_GITHUB_CLIENT_SECRET" = "ssm://${data.aws_ssm_parameter.sonarqube-github-client-secret.name}"
    "SONARQUBE_GITHUB_ORGANIZATIONS" = "ssm://${data.aws_ssm_parameter.sonarqube-github-organizations.name}"
    "SONARQUBE_ADMIN_USERNAME"       = "ssm://${data.aws_ssm_parameter.sonarqube-admin-username.name}"
    "SONARQUBE_ADMIN_PASSWORD"       = "ssm://${data.aws_ssm_parameter.sonarqube-admin-password.name}"
    "SONARQUBE_SEARCH_JVM_OPTS"      = "-Dnode.store.allow_mmapfs=false"
  }
  tags = var.tags
}

# --------------------------------------------------------------------------------------------------------------------
# Policies
# --------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "ssmtotask" {
  policy = data.aws_iam_policy_document.ssm_for_task.json
  role   = module.sonarqube_service.task_role_name
}

resource "aws_iam_role_policy" "kmstotask" {
  policy = data.aws_iam_policy_document.kms_for_task.json
  role   = module.sonarqube_service.task_role_name
}

# --------------------------------------------------------------------------------------------------------------------
# Route 53 and Certificate
# --------------------------------------------------------------------------------------------------------------------
data "aws_route53_zone" "aws_route53_zone" {
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "sonarqube" {
  zone_id = data.aws_route53_zone.aws_route53_zone.id
  name    = "${var.name_prefix}.${data.aws_route53_zone.aws_route53_zone.name}"
  type    = "CNAME"
  ttl     = 300
  records = [module.alb.dns_name]
}

module "certificate" {
  source           = "github.com/nsbno/terraform-aws-acm-certificate?ref=4d8dc64"
  hosted_zone_name = var.hosted_zone_name
  certificate_name = "${var.name_prefix}.${var.hosted_zone_name}"
  tags             = var.tags
}

# --------------------------------------------------------------------------------------------------------------------
# Security Group Rules
# --------------------------------------------------------------------------------------------------------------------
resource "aws_security_group_rule" "alb_ingress_443" {
  security_group_id = module.alb.security_group_id
  description       = "Allow Ingress to the ALB on port 443."
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "lb_grafana_ingress_rule" {
  security_group_id        = module.sonarqube_service.service_sg_id
  description              = "Allow LB to communicate the Fargate ECS service."
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 9000
  to_port                  = 9000
  source_security_group_id = module.alb.security_group_id
}

resource "aws_security_group_rule" "sonarqube_rds_ingress" {
  security_group_id        = module.sonarqube_rds.security_group_id
  description              = "Allow Sonarqube to communicate the database."
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = module.sonarqube_rds.port
  to_port                  = module.sonarqube_rds.port
  source_security_group_id = module.sonarqube_service.service_sg_id
}

# --------------------------------------------------------------------------------------------------------------------
# SSM Parameters
# --------------------------------------------------------------------------------------------------------------------

data "aws_ssm_parameter" "sonarqube-rds-username" {
  name = "/${var.name_prefix}/rds-username"
}

data "aws_ssm_parameter" "sonarqube-rds-password" {
  name = "/${var.name_prefix}/rds-password"
}

data "aws_ssm_parameter" "sonarqube-github-auth-enabled" {
  name = "/${var.name_prefix}/github-auth-enabled"
}

data "aws_ssm_parameter" "sonarqube-github-client-id" {
  name = "/${var.name_prefix}/github-client-id"
}

data "aws_ssm_parameter" "sonarqube-github-client-secret" {
  name = "/${var.name_prefix}/github-client-secret"
}

data "aws_ssm_parameter" "sonarqube-github-organizations" {
  name = "/${var.name_prefix}/github-organizations"
}

data "aws_ssm_parameter" "sonarqube-admin-username" {
  name = "/${var.name_prefix}/admin-username"
}

data "aws_ssm_parameter" "sonarqube-admin-password" {
  name = "/${var.name_prefix}/admin-password"
}

resource "aws_ssm_parameter" "sonarqube-rds-url" {
  name      = "/${var.name_prefix}/rds-url"
  type      = "SecureString"
  value     = "jdbc:postgresql://${module.sonarqube_rds.endpoint}/main"
  key_id    = var.parameters_key_arn
  overwrite = true
}

resource "aws_ssm_parameter" "sonarqube-base-url" {
  name      = "/${var.name_prefix}/base-url"
  type      = "SecureString"
  value     = "https://${aws_route53_record.sonarqube.fqdn}"
  key_id    = var.parameters_key_arn
  overwrite = true
}