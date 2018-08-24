# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# --------------------------------------------------------------------------------------------------------------------

variable "peer_owner_id" {
  description = "Account ID of the AWS account housing the VPC peering connection."
  type        = "string"
}

variable "vault_client_subnet_ids" {
  description = "Subnet ID(s) for the instance(s) being peered with the Vault VPC."
  type        = "list"
}

variable "vault_client_name" {
  description = "A label identifying the vault client being connected to use when tagging/naming resources."
  type        = "string"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "vault_vpc_id" {
  description = "ID for Vault's VPC"
  default     = "vpc-d762c8af"
  type        = "string"
}

variable "vault_server_aws_region" {
  description = "The AWS region hosting the vault client"
  default     = "us-east-1"
  type        = "string"
}

variable "vault_application_load_balancer_security_group_id" {
  description = "Security Group ID for the Application Load Balancer in front of Vault servers"
  default     = "sg-cb97a3b9"
  type        = "string"
}

variable "vault_route_table_id" {
  description = "Route table ID for Vault nodes in their VPC"
  default     = "rtb-8d622af7"
  type        = "string"
}

variable "add_alb_sg_rule_for_client_vpc_cidr" {
  description = "Optional variable to allow requests to the Vault Application Load Balancer by the entire CIDR range of the client VPC. Set this value to 'true' (or anything other than a blank string) to enable."
  type        = "string"
  default     = ""
}
