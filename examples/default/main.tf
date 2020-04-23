provider "aws" {
  version = "~> 2.54"
  region  = "eu-west-1"
}

module "sonarqube" {
  source      = "../../"
  name_prefix = "sonarqube-example"
  tags = {
    terraform   = "true"
    environment = "example"
    application = "sonarqube"
  }
  hosted_zone_name   = "example.com"
  parameters_key_arn = "<arn of key from init>"
}