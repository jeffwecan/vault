# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# --------------------------------------------------------------------------------------------------------------------
variable "vault_client_gcp_region" {
  description = "The GCP region hosting the vault client."
}

variable "vault_client_gcp_network_name" {
  description = "The GCP network name that houses the vault client."
}

variable "vault_client_subnet_cidr" {
  description = "The subnet of the vault client."
}

variable "vault_client_name" {
  description = "A label identifying the vault client being connected to use when tagging/naming resources. Most not contain underscores. See: <GCP docs on name tags>"
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

variable "gcp_tunnel1_vpn_gw_asn" {
  description = "Tunnel 1 - Virtual Private Gateway ASN, from the AWS VPN Customer Gateway Configuration"
  default = "7224"
}

variable "gcp_tunnel1_customer_gw_inside_network_cidr" {
  description = "Tunnel 1 - Customer Gateway from Inside IP Address CIDR block, from AWS VPN Customer Gateway Configuration"
  default = "30"
}

variable "gcp_tunnel2_vpn_gw_asn" {
  description = "Tunnel 2 - Virtual Private Gateway ASN, from the AWS VPN Customer Gateway Configuration"
  default = "7224"
}

variable "gcp_tunnel2_customer_gw_inside_network_cidr" {
  description = "Tunnel 2 - Customer Gateway from Inside IP Address CIDR block, from AWS VPN Customer Gateway Configuration"
  default = "30"
}
