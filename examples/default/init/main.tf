provider "aws" {
  version = "~> 2.54"
  region  = "eu-west-1"
}

locals {
  name_prefix = "sonarqube-example"
  tags = {
    terraform   = "true"
    environment = "example"
    application = "sonarqube"
  }
}

module "sonarqube-init" {
  name_prefix = "${local.name_prefix}"
  source      = "../../../modules/init"
  tags        = local.tags
}

output "parameters_key_arn" {
  description = "The arn of the key used to encrypt the parameters"
  value       = module.sonarqube-init.parameters_key_arn
}