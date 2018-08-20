# ---------------------------------------------------------------------------------------------------------------------
# Configures VPC peering and/or VPN interconect resources to allow Vault clients to communicate with Vault nodes over
# private subnets.
# ---------------------------------------------------------------------------------------------------------------------
provider "google" {
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
  id       = "${var.vault_vpc_id}"
}

data "aws_route_table" "vault" {
  provider       = "aws.vault_cluster"
  route_table_id = "${var.vault_route_table_id}"
}

/*
 * Terraform networking data for GCP.
 */
data "google_compute_network" "vault_client" {
  provider = "google.vault_client"
  name     = "${var.vault_client_gcp_network_name}"
}

/*
 * Connect VPN resources to the Vault VPC
 */
resource "aws_vpn_gateway_route_propagation" "vault_client_to_vault_route" {
  provider       = "aws.vault_cluster"
  vpn_gateway_id = "${aws_vpn_gateway.vault_client_to_vault_vpn_gateway.id}"
  route_table_id = "${data.aws_route_table.vault.id}"
}

/*
 * Establish routes and security group rules allowing Vault clients to reach the Vault application load balancer
 */
resource "aws_security_group_rule" "allow_vault_client_to_vault_loadbalancer" {
  provider    = "aws.vault_cluster"
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["${var.vault_client_subnet_cidr}"]

  security_group_id = "${var.vault_application_load_balancer_security_group_id}"
}

/*
 * ---------- AWS Side of the VPN Connection to GCP / ${var.vault_client_name}----------
 */
resource "aws_vpn_gateway" "vault_client_to_vault_vpn_gateway" {
  provider = "aws.vault_cluster"
  vpc_id   = "${data.aws_vpc.vault.id}"

  tags {
    "Name" = "${var.vault_client_name}_to_vault_vpn_gateway"
  }
}

resource "aws_customer_gateway" "vault_client_to_vault_customer_gateway" {
  provider   = "aws.vault_cluster"
  bgp_asn    = 65000
  ip_address = "${google_compute_address.vault_client_to_vault_vpn_ip.address}"
  type       = "ipsec.1"

  tags {
    "Name" = "${var.vault_client_name}_to_vault_customer_gw"
  }
}

resource "aws_vpn_connection" "vault_client_to_vault_vpn_connection_1" {
  provider            = "aws.vault_cluster"
  vpn_gateway_id      = "${aws_vpn_gateway.vault_client_to_vault_vpn_gateway.id}"
  customer_gateway_id = "${aws_customer_gateway.vault_client_to_vault_customer_gateway.id}"
  type                = "ipsec.1"
  static_routes_only  = false

  tags {
    "Name" = "${var.vault_client_name}_to_vault_vpn_connection_1"
  }
}

/*
 * ----------VPN Connection at GCP----------
 */
resource "google_compute_address" "vault_client_to_vault_vpn_ip" {
  provider = "google.vault_client"
  name     = "${var.vault_client_name}-to-vault-vpn-ip"
  region   = "${var.vault_client_gcp_region}"
}

resource "google_compute_vpn_gateway" "vault_client_to_vault_vpn_gateway" {
  provider = "google.vault_client"
  name     = "${var.vault_client_name}-to-vault-vpn-gateway-${var.vault_client_gcp_region}"
  network  = "${data.google_compute_network.vault_client.name}"
  region   = "${var.vault_client_gcp_region}"
}

resource "google_compute_forwarding_rule" "fr_esp" {
  provider    = "google.vault_client"
  name        = "fr-esp"
  ip_protocol = "ESP"
  ip_address  = "${google_compute_address.vault_client_to_vault_vpn_ip.address}"
  target      = "${google_compute_vpn_gateway.vault_client_to_vault_vpn_gateway.self_link}"
}

resource "google_compute_forwarding_rule" "fr_udp500" {
  provider    = "google.vault_client"
  name        = "fr-udp500"
  ip_protocol = "UDP"
  port_range  = "500-500"
  ip_address  = "${google_compute_address.vault_client_to_vault_vpn_ip.address}"
  target      = "${google_compute_vpn_gateway.vault_client_to_vault_vpn_gateway.self_link}"
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  provider    = "google.vault_client"
  name        = "fr-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500-4500"
  ip_address  = "${google_compute_address.vault_client_to_vault_vpn_ip.address}"
  target      = "${google_compute_vpn_gateway.vault_client_to_vault_vpn_gateway.self_link}"
}

/*
 * ----------VPN Tunnel1----------
 */
resource "google_compute_vpn_tunnel" "vault_client_to_vault_vpn_tunnel1" {
  provider      = "google.vault_client"
  name          = "${var.vault_client_name}-to-vault-vpn-tunnel1"
  peer_ip       = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.tunnel1_address}"
  shared_secret = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.tunnel1_preshared_key}"
  ike_version   = 1

  target_vpn_gateway = "${google_compute_vpn_gateway.vault_client_to_vault_vpn_gateway.self_link}"

  router = "${google_compute_router.vault_client_to_vault_router1.name}"

  depends_on = [
    "google_compute_forwarding_rule.fr_esp",
    "google_compute_forwarding_rule.fr_udp500",
    "google_compute_forwarding_rule.fr_udp4500",
  ]
}

resource "google_compute_router" "vault_client_to_vault_router1" {
  provider = "google.vault_client"
  name     = "${var.vault_client_name}-to-vault-router1"
  region   = "${var.vault_client_gcp_region}"
  network  = "${data.google_compute_network.vault_client.name}"

  bgp {
    asn = "${aws_customer_gateway.vault_client_to_vault_customer_gateway.bgp_asn}"
  }
}

resource "google_compute_router_peer" "vault_client_to_vault_router1_peer" {
  provider        = "google.vault_client"
  name            = "${var.vault_client_name}-to-vault-bgp1"
  router          = "${google_compute_router.vault_client_to_vault_router1.name}"
  region          = "${google_compute_router.vault_client_to_vault_router1.region}"
  peer_ip_address = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.tunnel1_vgw_inside_address}"
  peer_asn        = "${var.gcp_tunnel1_vpn_gw_asn}"
  interface       = "${google_compute_router_interface.vault_client_to_vault_router_interface1.name}"
}

resource "google_compute_router_interface" "vault_client_to_vault_router_interface1" {
  provider   = "google.vault_client"
  name       = "${var.vault_client_name}-to-vault-interface1"
  router     = "${google_compute_router.vault_client_to_vault_router1.name}"
  region     = "${google_compute_router.vault_client_to_vault_router1.region}"
  ip_range   = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.tunnel1_cgw_inside_address}/${var.gcp_tunnel1_customer_gw_inside_network_cidr}"
  vpn_tunnel = "${google_compute_vpn_tunnel.vault_client_to_vault_vpn_tunnel1.name}"
}

/*
 * ----------VPN Tunnel2----------
 */
resource "google_compute_vpn_tunnel" "vault_client_to_vault_vpn_tunnel2" {
  provider      = "google.vault_client"
  name          = "${var.vault_client_name}-to-vault-vpn-tunnel2"
  peer_ip       = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.tunnel2_address}"
  shared_secret = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.tunnel2_preshared_key}"
  ike_version   = 1

  target_vpn_gateway = "${google_compute_vpn_gateway.vault_client_to_vault_vpn_gateway.self_link}"

  router = "${google_compute_router.vault_client_to_vault_router2.name}"

  depends_on = [
    "google_compute_forwarding_rule.fr_esp",
    "google_compute_forwarding_rule.fr_udp500",
    "google_compute_forwarding_rule.fr_udp4500",
  ]
}

resource "google_compute_router" "vault_client_to_vault_router2" {
  provider = "google.vault_client"
  name     = "${var.vault_client_name}-to-vault-router2"
  region   = "${var.vault_client_gcp_region}"
  network  = "${data.google_compute_network.vault_client.name}"

  bgp {
    asn = "${aws_customer_gateway.vault_client_to_vault_customer_gateway.bgp_asn}"
  }
}

resource "google_compute_router_peer" "vault_client_to_vault_router2_peer" {
  provider        = "google.vault_client"
  name            = "${var.vault_client_name}-to-vault-bgp2"
  router          = "${google_compute_router.vault_client_to_vault_router2.name}"
  region          = "${google_compute_router.vault_client_to_vault_router2.region}"
  peer_ip_address = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.tunnel2_vgw_inside_address}"
  peer_asn        = "${var.gcp_tunnel2_vpn_gw_asn}"
  interface       = "${google_compute_router_interface.vault_client_to_vault_router_interface2.name}"
}

resource "google_compute_router_interface" "vault_client_to_vault_router_interface2" {
  provider   = "google.vault_client"
  name       = "${var.vault_client_name}-to-vault-interface2"
  router     = "${google_compute_router.vault_client_to_vault_router2.name}"
  region     = "${google_compute_router.vault_client_to_vault_router2.region}"
  ip_range   = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.tunnel2_cgw_inside_address}/${var.gcp_tunnel2_customer_gw_inside_network_cidr}"
  vpn_tunnel = "${google_compute_vpn_tunnel.vault_client_to_vault_vpn_tunnel2.name}"
}
