output "vault_bastion1_ec2_instance_id" {
  value = "${module.vault_bastion1_instance.ec2_instance_id}"
}

output "vault_bastion1_root_block_device_vol_id" {
  value = "${module.vault_bastion1_instance.root_block_device_vol_id}"
}

output "vault_bastion1_ami_id" {
  value = "${module.vault_bastion1_instance.ami_id}"
}

output "vault_bastion1_network_iterface_id" {
  value = "${module.vault_bastion1_instance.network_iterface_id}"
}

output "vault_bastion1_eip_id" {
  value = "${module.vault_bastion1_instance.eip_id}"
}

output "vault_bastion1_public_ip_address" {
  value = "${module.vault_bastion1_instance.public_ip_address}"
}

output "vault_bastion1_private_ip_address" {
  value = "${module.vault_bastion1_instance.private_ip_address}"
}

output "vault_bastion1_private_ip_dns_record" {
  value = "${module.vault_bastion1_instance.private_ip_dns_record}"
}

output "vault_bastion_svc_dns_name" {
  value = "${module.vault_bastion_svc_dns_record.aws_dns_name}"
}
