output "vault_to_corporate_core_route_id" {
  value = "${module.corporate_core_metrics_to_vault.vault_to_vault_client_route_id}"
}

output "corporate_core_to_vault_route_id" {
  value = "${module.corporate_core_metrics_to_vault.vault_client_to_vault_route_id}"
}

output "allow_corporate_core_to_vault_loadbalancer_id" {
  value = "${module.corporate_core_metrics_to_vault.allow_vault_client_to_vault_loadbalancer_id}"
}

output "route_propagation_vault_client_to_vault_route_id" {
  value = "${module.dev_cm_to_vault.route_propagation_vault_client_to_vault_route_id}"
}

output "allow_vault_client_to_vault_loadbalancer_id" {
  value = "${module.dev_cm_to_vault.allow_vault_client_to_vault_loadbalancer_id}"
}

output "vault_vpn_gateway_id" {
  value = "${module.dev_cm_to_vault.vault_vpn_gateway_id}"
}

output "vault_customer_gateway_id" {
  value = "${module.dev_cm_to_vault.vault_customer_gateway_id}"
}

output "load_balancer_dns_name" {
  value = "${module.vault_elbv2_dns_record.load_balancer_dns_name}"
}

output "load_balancer_resource_name" {
  value = "${module.vault_elbv2_dns_record.load_balancer_resource_name}"
}

output "aws_dns_zone_name" {
  value = "${module.vault_elbv2_dns_record.aws_dns_zone_name}"
}

output "aws_dns_name" {
  value = "${module.vault_elbv2_dns_record.aws_dns_name}"
}
