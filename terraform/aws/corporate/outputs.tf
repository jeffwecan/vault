output "vault_to_corporate_core_route_ids" {
  value = "${module.corporate_core_to_vault.vault_to_vault_client_route_ids}"
}

output "corporate_core_to_vault_route_id" {
  value = "${module.corporate_core_to_vault.vault_client_to_vault_route_id}"
}

output "vault_to_cm_route_id" {
  value = "${module.cm_to_vault.vault_to_vault_client_route_ids}"
}

output "cm_to_vault_route_id" {
  value = "${module.cm_to_vault.vault_client_to_vault_route_id}"
}

output "allow_cm_to_vault_loadbalancer_id" {
  value = "${module.cm_to_vault.allow_vault_client_to_vault_loadbalancer_id}"
}

output "vault_to_jenkins_route_id" {
  value = "${module.jenkins_to_vault.vault_to_vault_client_route_ids}"
}

output "jenkins_to_vault_route_id" {
  value = "${module.jenkins_to_vault.vault_client_to_vault_route_id}"
}

output "allow_jenkins_to_vault_loadbalancer_id" {
  value = "${module.jenkins_to_vault.allow_vault_client_to_vault_loadbalancer_id}"
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

output "heroku_space_peering_pcx_id" {
  value = "${aws_vpc_peering_connection.heroku_wpengine_corporate_space_to_vault.id}"
}
