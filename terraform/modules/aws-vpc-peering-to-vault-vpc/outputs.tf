output "vault_to_vault_client_route_ids" {
  value = "${aws_route.vault_to_vault_client_route.*.id}"
}

output "vault_client_to_vault_route_id" {
  value = "${aws_route.vault_client_to_vault_route.*.id}"
}
