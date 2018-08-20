output "route_propagation_vault_client_to_vault_route_id" {
  value = "${aws_vpn_gateway_route_propagation.vault_client_to_vault_route.id}"
}

output "allow_vault_client_to_vault_loadbalancer_id" {
  value = "${aws_security_group_rule.allow_vault_client_to_vault_loadbalancer.id}"
}

output "vault_vpn_gateway_id" {
  value = "${aws_vpn_gateway.vault_client_to_vault_vpn_gateway.id}"
}

output "vault_customer_gateway_id" {
  value = "${aws_customer_gateway.vault_client_to_vault_customer_gateway.id}"
}

output "vault_vpn_connection_1_id" {
  value = "${aws_vpn_connection.vault_client_to_vault_vpn_connection_1.id}"
}

output "vault_client_to_vault_vpn_ip_id" {
  value = "${google_compute_address.vault_client_to_vault_vpn_ip.id}"
}

output "vault_client_to_vault_vpn_gateway_id" {
  value = "${google_compute_vpn_gateway.vault_client_to_vault_vpn_gateway.id}"
}

output "gcp_fr_esp_id" {
  value = "${google_compute_forwarding_rule.fr_esp.id}"
}

output "gcp_fr_udp500_id" {
  value = "${google_compute_forwarding_rule.fr_udp500.id}"
}

output "vault_client_to_vault_vpn_tunnel1" {
  value = "${google_compute_vpn_tunnel.vault_client_to_vault_vpn_tunnel1.id}"
}

output "vault_client_to_vault_router1_id" {
  value = "${google_compute_router.vault_client_to_vault_router1.id}"
}

output "vault_client_to_vault_router1_peer_id" {
  value = "${google_compute_router_peer.vault_client_to_vault_router1_peer.id}"
}

output "vault_client_to_vault_router_interface1_id" {
  value = "${google_compute_router_interface.vault_client_to_vault_router_interface1.id}"
}

output "vault_client_to_vault_vpn_tunnel2" {
  value = "${google_compute_vpn_tunnel.vault_client_to_vault_vpn_tunnel2.id}"
}

output "vault_client_to_vault_router2_id" {
  value = "${google_compute_router.vault_client_to_vault_router2.id}"
}

output "vault_client_to_vault_router2_peer_id" {
  value = "${google_compute_router_peer.vault_client_to_vault_router2_peer.id}"
}

output "vault_client_to_vault_router_interface2_id" {
  value = "${google_compute_router_interface.vault_client_to_vault_router_interface2.id}"
}
