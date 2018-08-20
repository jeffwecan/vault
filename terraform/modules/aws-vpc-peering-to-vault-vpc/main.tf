# ---------------------------------------------------------------------------------------------------------------------
# Configures VPC peering resources to allow Vault clients to communicate with Vault nodes over private subnets.
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  # 0.11.1 is required for the providers map attribute for our modules
  required_version = ">= 0.11.1"
}

provider "aws" {
  alias = "vault_client"
}

provider "aws" {
  alias = "vault_cluster"
}

/*
 * Terraform networking data for AWS.
 */
data "aws_vpc" "vault" {
  provider = "aws.vault_cluster"
  id = "${var.vault_vpc_id}"
}

data "aws_route_table" "vault" {
  provider = "aws.vault_cluster"
  route_table_id = "${var.vault_route_table_id}"
}

data "aws_subnet" "vault_client" {
  provider = "aws.vault_client"
  id = "${var.vault_client_subnet_id}"
}

data "aws_route_table" "vault_client" {
  provider = "aws.vault_client"
  subnet_id = "${data.aws_subnet.vault_client.id}"
}


/*
 * Connect VPC resources to the Vault VPC
 */
resource "aws_vpc_peering_connection" "vault_client_to_vault" {
  provider = "aws.vault_cluster"
  peer_owner_id = "${var.peer_owner_id}"
  peer_vpc_id   = "${data.aws_vpc.vault.id}"
  vpc_id        = "${data.aws_subnet.vault_client.vpc_id}"
  auto_accept   = true

  tags {
    Name = "${var.vault_client_name}_to_vault"
  }
}


/*
 * Establish routes and security group rules allowing Vault clients to reach the Vault application load balancer
 */
resource "aws_route" "vault_to_vault_client_route" {
  provider = "aws.vault_cluster"
  route_table_id            = "${data.aws_route_table.vault.id}"
  destination_cidr_block    = "${data.aws_subnet.vault_client.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.vault_client_to_vault.id}"
}

resource "aws_route" "vault_client_to_vault_route" {
  provider = "aws.vault_client"
  route_table_id            = "${data.aws_route_table.vault_client.id}"
  destination_cidr_block    = "${data.aws_vpc.vault.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.vault_client_to_vault.id}"
}

resource "aws_security_group_rule" "allow_vault_client_to_vault_loadbalancer" {
  provider = "aws.vault_cluster"
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  cidr_blocks     = ["${data.aws_subnet.vault_client.cidr_block}"]

  security_group_id = "${var.vault_application_load_balancer_security_group_id}"
}

