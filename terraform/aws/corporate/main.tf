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
  alias = "corporate"
  version = "~> 1.13.0"
  region = "${var.aws_corporate_region}"
  assume_role {
    role_arn     = "${var.aws_corporate_role_arn}"
    session_name = "terraform_corporate_vault_networking"
  }
}

provider "aws" {
  alias = "corporate_dns"
  version = "~> 1.13.0"
  region = "${var.aws_corporate_region}"
  assume_role {
    role_arn     = "${var.aws_corporate_dns_role_arn}"
    session_name = "terraform_corporate_vault_dns"
  }
}


module "corporate_core_metrics_to_vault" {
  source = "git@github.com:wpengine/infraform.git//modules/aws-vpc-peering-to-vault-vpc?ref=v1.41"

  peer_owner_id = "${var.peer_owner_id}"
  vault_client_subnet_id = "${var.corporate_core_metrics_subnet_id}"
  vault_client_name = "metricsapp"
  vault_vpc_id = "${var.vault_vpc_id}"
  vault_application_load_balancer_security_group_id = "${var.vault_load_balancer_security_group_id}"
  vault_route_table_id = "${var.vault_route_table_id}"
  providers = {
    "aws.vault_client" = "aws.corporate"
    "aws.vault_cluster" = "aws.corporate"
  }
}

module "cm_to_vault" {
  source = "git@github.com:wpengine/infraform.git//modules/aws-vpc-peering-to-vault-vpc?ref=v1.41"

  peer_owner_id = "${var.peer_owner_id}"
  vault_client_subnet_id = "${var.cm_subnet_id}"
  vault_client_name = "cm"
  vault_vpc_id = "${var.vault_vpc_id}"
  vault_application_load_balancer_security_group_id = "${var.vault_load_balancer_security_group_id}"
  vault_route_table_id = "${var.vault_route_table_id}"
  providers = {
    "aws.vault_client" = "aws.corporate"
    "aws.vault_cluster" = "aws.corporate"
  }
}

module "jenkins_to_vault" {
  source = "git@github.com:wpengine/infraform.git//modules/aws-vpc-peering-to-vault-vpc?ref=v1.41"

  peer_owner_id = "${var.peer_owner_id}"
  vault_client_subnet_id = "${var.jenkins_subnet_id}"
  vault_client_name = "jenkins"
  vault_vpc_id = "${var.vault_vpc_id}"
  vault_application_load_balancer_security_group_id = "${var.vault_load_balancer_security_group_id}"
  vault_route_table_id = "${var.vault_route_table_id}"
  providers = {
    "aws.vault_client" = "aws.corporate"
    "aws.vault_cluster" = "aws.corporate"
  }
}

module "vault_elbv2_dns_record" {
  source = "git@github.com:wpengine/infraform.git//modules/dns-for-aws-elbv2?ref=v1.41"

  name = "${var.vault_dns_record_name}"
  load_balancer_arn = "${var.vault_load_balancer_arn}"
  providers = {
    "aws.dns" = "aws.corporate_dns"
    "aws.load_balancer" = "aws.corporate"
  }
}
