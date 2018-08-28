variable "vault_cf_stack_outputs" {
  type        = "map"
  description = "Map of outputs from the Vault CloudFormation stack"
}

variable "instance_dns_zone" {
  type        = "string"
  description = "DNS zone to use when creating records for EC2 instances."
}

variable "service_dns_zone" {
  type        = "string"
  description = "DNS zone to use when creating records for services / load balancers."
}

variable "ssh_key_name" {
  type        = "string"
  description = "Name of the AWS EC2-hosted SSH public key to grant SSH access to for the instance."
}

variable "vault_cf_stack_name" {
  type        = "string"
  description = "Name of the CloudFormation stack holding related Vault cluster resources."
  default     = "vault"
}

variable "vault_bastion1_instance_name" {
  type        = "string"
  description = "Name for the Vault bastion instance."
  default     = "vault-bastion1"
}

variable "vault_bastion1_dns_name" {
  description = "Subdomain to use for the instance's corresponding DNS record. This is pointed to the decription Elastic IP Address. If not provided, this defaults to the instance_name input."
  type        = "string"
  default     = ""
}

variable "vault_bastion_instance_type" {
  type        = "string"
  description = "EC2 instance type for bastion instances."
  default     = "t3.small"
}

variable "vault_bastion_disk_size" {
  type        = "string"
  description = "EC2 disk size for bastion instances."
  default     = "16"
}
