# ---------------------------------------------------------------------------------------------------------------------
# Configures VPC peering and/or VPN interconect resources to allow Vault clients to communicate with Vault nodes over
# private subnets.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # 0.11.3 is the current version in our public terraform image
  # see: https://github.com/wpengine/base-images-public/tree/master/gcloud/terraform
  required_version = "0.11.7"
}

provider "aws" {
  alias   = "corporate"
  version = "~> 1.13.0"
  region  = "${var.aws_corporate_region}"

  assume_role {
    role_arn     = "${var.aws_corporate_role_arn}"
    session_name = "terraform_corporate_vault_networking"
  }
}

provider "aws" {
  alias   = "corporate_dns"
  version = "~> 1.13.0"
  region  = "${var.aws_corporate_region}"

  assume_role {
    role_arn     = "${var.aws_corporate_dns_role_arn}"
    session_name = "terraform_corporate_vault_dns"
  }
}

# Load the details of the specified "corporate_core" CloudFormation stack.
data "aws_cloudformation_stack" "vault" {
  provider = "aws.corporate"
  name     = "${var.vault_cf_stack_name}"
}

# Load the details of the specified "corporate_core" CloudFormation stack.
data "aws_cloudformation_stack" "corporate_core" {
  provider = "aws.corporate"
  name     = "${var.corporate_core_cf_stack_name}"
}

module "corporate_core_to_vault" {
  source = "../../modules/aws-vpc-peering-to-vault-vpc"

  peer_owner_id = "${var.peer_owner_id}"

  vault_client_subnet_ids = [
    "${data.aws_cloudformation_stack.corporate_core.outputs.AZ1Subnet}",
    "${data.aws_cloudformation_stack.corporate_core.outputs.AZ2Subnet}",
    "${data.aws_cloudformation_stack.corporate_core.outputs.AZ3Subnet}",
    "${data.aws_cloudformation_stack.corporate_core.outputs.AZ4Subnet}",
  ]

  vault_client_name                                 = "corporate_core"
  vault_vpc_id                                      = "${data.aws_cloudformation_stack.vault.outputs.VaultVPC}"
  vault_application_load_balancer_security_group_id = "${data.aws_cloudformation_stack.vault.outputs.VaultApplicationLoadBalancerSecurityGroup}"
  vault_route_table_id                              = "${data.aws_cloudformation_stack.vault.outputs.RouteTable}"
  add_alb_sg_rule_for_client_vpc_cidr               = true

  providers = {
    "aws.vault_client"  = "aws.corporate"
    "aws.vault_cluster" = "aws.corporate"
  }
}

resource "aws_security_group_rule" "allow_vault_server_to_metricsdb_mysql" {
  provider                 = "aws.corporate"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = "${data.aws_cloudformation_stack.vault.outputs.VaultServersSecurityGroup}"

  security_group_id = "${data.aws_cloudformation_stack.corporate_core.outputs.sgMetricsDb}"
}

module "cm_to_vault" {
  source = "../../modules/aws-vpc-peering-to-vault-vpc"

  peer_owner_id                                     = "${var.peer_owner_id}"
  vault_client_subnet_ids                           = "${var.cm_subnet_ids}"
  vault_client_name                                 = "cm"
  vault_vpc_id                                      = "${data.aws_cloudformation_stack.vault.outputs.VaultVPC}"
  vault_application_load_balancer_security_group_id = "${data.aws_cloudformation_stack.vault.outputs.VaultApplicationLoadBalancerSecurityGroup}"
  vault_route_table_id                              = "${data.aws_cloudformation_stack.vault.outputs.RouteTable}"

  providers = {
    "aws.vault_client"  = "aws.corporate"
    "aws.vault_cluster" = "aws.corporate"
  }
}

module "jenkins_to_vault" {
  source = "../../modules/aws-vpc-peering-to-vault-vpc"

  peer_owner_id                                     = "${var.peer_owner_id}"
  vault_client_subnet_ids                           = "${var.jenkins_subnet_ids}"
  vault_client_name                                 = "jenkins"
  vault_vpc_id                                      = "${data.aws_cloudformation_stack.vault.outputs.VaultVPC}"
  vault_application_load_balancer_security_group_id = "${data.aws_cloudformation_stack.vault.outputs.VaultApplicationLoadBalancerSecurityGroup}"
  vault_route_table_id                              = "${data.aws_cloudformation_stack.vault.outputs.RouteTable}"

  providers = {
    "aws.vault_client"  = "aws.corporate"
    "aws.vault_cluster" = "aws.corporate"
  }
}

module "zabbix_to_vault" {
  source = "../../modules/aws-vpc-peering-to-vault-vpc"

  peer_owner_id                                     = "${var.peer_owner_id}"
  vault_client_subnet_ids                           = "${var.zabbix_subnet_ids}"
  vault_client_name                                 = "zabbix"
  vault_vpc_id                                      = "${data.aws_cloudformation_stack.vault.outputs.VaultVPC}"
  vault_application_load_balancer_security_group_id = "${data.aws_cloudformation_stack.vault.outputs.VaultApplicationLoadBalancerSecurityGroup}"
  vault_route_table_id                              = "${data.aws_cloudformation_stack.vault.outputs.RouteTable}"

  providers = {
    "aws.vault_client"  = "aws.corporate"
    "aws.vault_cluster" = "aws.corporate"
  }
}

module "vault_elbv2_dns_record" {
  source = "git@github.com:wpengine/infraform.git//modules/dns-for-aws-elbv2?ref=v1.42"

  name              = "${var.vault_dns_record_name}"
  load_balancer_arn = "${data.aws_cloudformation_stack.vault.outputs.VaultApplicationLoadBalancer}"

  providers = {
    "aws.dns"           = "aws.corporate_dns"
    "aws.load_balancer" = "aws.corporate"
  }
}

resource "aws_vpc_peering_connection" "heroku_wpengine_corporate_space_to_vault" {
  provider      = "aws.corporate"
  peer_owner_id = "${var.heroku_wpengine_corporate_space_peer_owner}"
  peer_vpc_id   = "${var.heroku_wpengine_corporate_space_vpc_id}"
  vpc_id        = "${data.aws_cloudformation_stack.vault.outputs.VaultVPC}"

  tags {
    "CreatingResource" = "github.com/wpengine/vault"
  }
}

/*
 * Establish routes and security group rules allowing Heroku apps in our private space to reach the Vault application load balancer
 */
resource "aws_route" "vault_to_heroku_wpengine_corporate_space_route" {
  provider = "aws.corporate"

  # Create one route table entry for each heroku dyno CIDR
  count                     = "${length(var.heroku_wpengine_corporate_space_dyno_cidrs)}"
  route_table_id            = "${data.aws_cloudformation_stack.vault.outputs.RouteTable}"
  destination_cidr_block    = "${var.heroku_wpengine_corporate_space_dyno_cidrs[count.index]}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.heroku_wpengine_corporate_space_to_vault.id}"
}

resource "aws_security_group_rule" "allow_heroku_wpengine_corporate_space_to_vault_loadbalancer" {
  provider    = "aws.corporate"
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["${var.heroku_wpengine_corporate_space_dyno_cidrs}"]

  security_group_id = "${data.aws_cloudformation_stack.vault.outputs.VaultApplicationLoadBalancerSecurityGroup}"
}

/*
 * Set up a route53 -> VPC associate for Vault so it can perform queries on our corporate.private zone.
 * E.g., for database plugin configuration that keys on records like "metricsdb.corporate.private
*/
data "aws_route53_zone" "corprate_private" {
  provider     = "aws.corporate"
  name         = "${var.dns_private_corporate_zone}"
  private_zone = true
}

resource "aws_route53_zone_association" "vault" {
  provider = "aws.corporate"
  zone_id  = "${data.aws_route53_zone.corprate_private.zone_id}"
  vpc_id   = "${data.aws_cloudformation_stack.vault.outputs.VaultVPC}"
}

module "vault_bastion" {
  source = "../../modules/vault-bastion"

  vault_cf_stack_outputs = "${data.aws_cloudformation_stack.vault.outputs}"
  ssh_key_name           = "${var.instance_ssh_key_name}"
  instance_dns_zone      = "${var.instance_dns_zone}"
  service_dns_zone       = "${var.service_dns_zone}"

  providers = {
    "aws.bastion" = "aws.corporate"
    "aws.dns"     = "aws.corporate"
  }
}
