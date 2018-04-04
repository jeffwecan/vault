# ---------------------------------------------------------------------------------------------------------------------
# Configures VPC peering and/or VPN interconect resources to allow Vault clients to communicate with Vault nodes over
# private subnets.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # 0.11.1 is required for the providers map attribute for our modules
  required_version = ">= 0.11.1"
}

provider "aws" {
  alias = "development"
  version = "~> 1.13.0"
  region = "${var.aws_development_region}"
  assume_role {
    role_arn     = "${var.aws_development_role_arn}"
    session_name = "terraform_development_vault_networking"
  }
}

provider "aws" {
  alias = "corporate_dns"
  version = "~> 1.13.0"
  region = "${var.aws_corporate_region}"
  assume_role {
    role_arn     = "${var.aws_corporate_dns_role_arn}"
    session_name = "terraform_development_vault_dns"
  }
}

provider "google" {
  alias = "development"
  version = "~> 1.1"
  project = "${var.gcp_project}"
  region = "${var.gcp_region}"
}

module "corporate_core_metrics_to_vault" {
  source = "git@github.com:wpengine/infraform.git//modules/aws-vpc-peering-to-vault-vpc?ref=v1.40"

  vault_client_name = "metricsapp"
  vault_client_aws_region = "${var.aws_development_region}"
  vault_client_subnet_id = "${var.corporate_core_metrics_subnet_id}"
  peer_owner_id = "${var.peer_owner_id}"
  vault_vpc_id = "${var.vault_vpc_id}"
  vault_application_load_balancer_security_group_id = "${var.vault_load_balancer_security_group_id}"
  vault_route_table_id = "${var.vault_route_table_id}"
  providers = {
    "aws.vault_client" = "aws.development"
    "aws.vault_cluster" = "aws.development"
  }
}

module "dev_cm_to_vault" {
  source = "git@github.com:wpengine/infraform.git//modules/gcp-vpn-to-vault-vpc?ref=v1.40"

  vault_client_name = "dev-cm"
  vault_client_gcp_project = "${var.gcp_project}"
  vault_client_gcp_region = "${var.gcp_region}"
  vault_client_gcp_network_name = "${var.gcp_network_name}"
  vault_client_subnet_cidr = "${var.dev_cm_subnet_cidr}"
  vault_vpc_id = "${var.vault_vpc_id}"
  vault_application_load_balancer_security_group_id = "${var.vault_load_balancer_security_group_id}"
  vault_route_table_id = "${var.vault_route_table_id}"
  providers = {
    "google.vault_client" = "google.development"
    "aws.vault_cluster" = "aws.development"
  }
}

module "vault_elbv2_dns_record" {
  source = "git@github.com:wpengine/infraform.git//modules/dns-for-aws-elbv2?ref=v1.40"

  name = "${var.vault_dns_record_name}"
  load_balancer_arn = "${var.vault_load_balancer_arn}"
  providers = {
    "aws.dns" = "aws.corporate_dns"
    "aws.load_balancer" = "aws.development"
  }
}
