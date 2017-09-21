
module "private-tls-cert" {
  source = "github.com/hashicorp/terraform-aws-vault.git//modules/private-tls-cert?ref=v0.0.2"


  private_key_file_path = "${var.private_key_file_path}"
  ca_public_key_file_path = "${var.ca_public_key_file_path}"
  public_key_file_path = "${var.public_key_file_path}"
  owner = "${var.owner}"
  ip_addresses = "${var.ip_addresses}"
  validity_period_hours = "${var.validity_period_hours}"
  organization_name = "${var.organization_name}"
  ca_common_name = "${var.ca_common_name}"
  common_name = "${var.common_name}"
  dns_names = "${var.dns_names}"
}
