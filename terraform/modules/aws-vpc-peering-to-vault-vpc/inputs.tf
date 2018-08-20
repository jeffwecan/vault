# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# --------------------------------------------------------------------------------------------------------------------

variable "peer_owner_id" {
  description = "Account ID of the AWS account housing the VPC peering connection."
}

variable "vault_client_subnet_id" {
  description = "Subnet ID for the instance(s) being peered with the Vault VPC."
}

variable "vault_client_name" {
  description = "A label identifying the vault client being connected to use when tagging/naming resources."
}
# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "vault_vpc_id" {
  description = "ID for Vault's VPC"
  default     = "vpc-d762c8af"
}

variable "vault_server_aws_region" {
  description = "The AWS region hosting the vault client"
  default = "us-east-1"
}

variable "vault_application_load_balancer_security_group_id" {
  description = "Security Group ID for the Application Load Balancer in front of Vault servers"
  default     = "sg-cb97a3b9"
}

variable "vault_route_table_id" {
  description = "Route table ID for Vault nodes in their VPC"
  default     = "rtb-8d622af7"
}
