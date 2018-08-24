# ---------------------------------------------------------------------------------------------------------------------
# Configures VPC peering and/or VPN interconect resources to allow Vault clients to communicate with Vault nodes over
# private subnets.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # 0.11.3 is the current version in our public terraform image
  # see: https://github.com/wpengine/base-images-public/tree/master/gcloud/terraform
  required_version = "0.11.3"
}

provider "aws" {
  alias   = "development"
  version = "~> 1.13.0"
  region  = "${var.aws_development_region}"

  assume_role {
    role_arn     = "${var.aws_development_role_arn}"
    session_name = "terraform_development_vault_networking"
  }
}

provider "aws" {
  alias   = "corporate_dns"
  version = "~> 1.13.0"
  region  = "${var.aws_corporate_region}"

  assume_role {
    role_arn     = "${var.aws_corporate_dns_role_arn}"
    session_name = "terraform_development_vault_dns"
  }
}

provider "google" {
  alias   = "development"
  version = "~> 1.1"
  project = "${var.gcp_project}"
  region  = "${var.gcp_region}"
}

# Load the details of the specified "corporate_core" CloudFormation stack.
data "aws_cloudformation_stack" "corporate_core" {
  provider = "aws.development"
  name     = "${var.corporate_core_cf_stack_name}"
}

module "corporate_core_to_vault" {
  source = "../../modules/aws-vpc-peering-to-vault-vpc"

  vault_client_name = "corporate_core"

  vault_client_subnet_ids = [
    "${data.aws_cloudformation_stack.corporate_core.outputs.AZ1Subnet}",
    "${data.aws_cloudformation_stack.corporate_core.outputs.AZ2Subnet}",
    "${data.aws_cloudformation_stack.corporate_core.outputs.AZ3Subnet}",
    "${data.aws_cloudformation_stack.corporate_core.outputs.AZ4Subnet}",
  ]

  peer_owner_id                                     = "${var.peer_owner_id}"
  vault_vpc_id                                      = "${var.vault_vpc_id}"
  vault_application_load_balancer_security_group_id = "${var.vault_load_balancer_security_group_id}"
  vault_route_table_id                              = "${var.vault_route_table_id}"
  add_alb_sg_rule_for_client_vpc_cidr               = true

  providers = {
    "aws.vault_client"  = "aws.development"
    "aws.vault_cluster" = "aws.development"
  }
}

resource "aws_security_group_rule" "allow_vault_server_to_metricsdb_mysql" {
  provider                 = "aws.development"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = "${var.vault_security_group_id}"

  security_group_id = "${data.aws_cloudformation_stack.corporate_core.outputs.sgMetricsDb}"
}

module "dev_cm_to_vault" {
  source = "../../modules/gcp-vpn-to-vault-vpc"

  vault_client_name                                 = "dev-cm"
  vault_client_gcp_region                           = "${var.gcp_region}"
  vault_client_gcp_network_name                     = "${var.gcp_network_name}"
  vault_client_subnet_cidr                          = "${var.dev_cm_subnet_cidr}"
  vault_vpc_id                                      = "${var.vault_vpc_id}"
  vault_application_load_balancer_security_group_id = "${var.vault_load_balancer_security_group_id}"
  vault_route_table_id                              = "${var.vault_route_table_id}"

  providers = {
    "google.vault_client" = "google.development"
    "aws.vault_cluster"   = "aws.development"
  }
}

module "zabbix_to_vault" {
  source = "../../modules/aws-vpc-peering-to-vault-vpc"

  peer_owner_id                                     = "${var.peer_owner_id}"
  vault_client_subnet_ids                           = "${var.zabbix_subnet_ids}"
  vault_client_name                                 = "zabbix"
  vault_vpc_id                                      = "${var.vault_vpc_id}"
  vault_application_load_balancer_security_group_id = "${var.vault_load_balancer_security_group_id}"
  vault_route_table_id                              = "${var.vault_route_table_id}"

  providers = {
    "aws.vault_client"  = "aws.development"
    "aws.vault_cluster" = "aws.development"
  }
}

module "vault_elbv2_dns_record" {
  source = "git@github.com:wpengine/infraform.git//modules/dns-for-aws-elbv2?ref=v1.42"

  name              = "${var.vault_dns_record_name}"
  load_balancer_arn = "${var.vault_load_balancer_arn}"

  providers = {
    "aws.dns"           = "aws.corporate_dns"
    "aws.load_balancer" = "aws.development"
  }
}

/*
 * Set up a route53 -> VPC associate for Vault so it can perform queries on our corporate.private zone.
 * E.g., for database plugin configuration that keys on records like "metricsdb.corporate.private
*/
data "aws_route53_zone" "corprate_private" {
  provider     = "aws.development"
  name         = "${var.dns_private_corporate_zone}"
  private_zone = true
}

resource "aws_route53_zone_association" "vault" {
  provider = "aws.development"
  zone_id  = "${data.aws_route53_zone.corprate_private.zone_id}"
  vpc_id   = "${var.vault_vpc_id}"
}
