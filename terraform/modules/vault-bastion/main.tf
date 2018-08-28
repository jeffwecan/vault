provider "aws" {
  alias = "bastion"
}

provider "aws" {
  alias = "dns"
}

provider "cloudflare" {}

resource "aws_security_group" "vault_bastions" {
  provider = "aws.bastion"

  name        = "VaultBastions"
  description = "Allow all SSH and Zabbix traffic for vault bastion nodes"
  vpc_id      = "${var.vault_cf_stack_outputs["VaultVPC"]}"

  ingress {
    from_port   = "-1"
    to_port     = "-1"
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 10050
    to_port     = 10050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Redefining the VPC-based security group default egress rule as Terraform removes it otherwise
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Application       = "${var.vault_cf_stack_name}"
    MaintainedBy      = "terraform"
    DeployingCodePath = "${path.root}"
    Environment       = "development"
  }
}

resource "aws_iam_role" "vault_bastions" {
  provider = "aws.bastion"

  name = "VaultBastions"
  path = "/wpengine/instances/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "bastions" {
  provider = "aws.bastion"

  name = "VaultBastions"
  role = "${aws_iam_role.vault_bastions.name}"
}

module "vault_bastion1_instance" {
  source = "git@github.com:wpengine/corpraform.git//terraform/modules/corporate_ec2_instance"

  instance_name             = "${var.vault_bastion1_instance_name}"
  dns_name                  = "${var.vault_bastion1_dns_name}"
  dns_zone                  = "${var.instance_dns_zone}"
  volume_size               = "${var.vault_bastion_disk_size}"
  instance_type             = "${var.vault_bastion_instance_type}"
  ssh_key_name              = "${var.ssh_key_name}"
  subnet_id                 = "${var.vault_cf_stack_outputs["AZ1Subnet"]}"
  iam_instance_profile      = "${aws_iam_instance_profile.bastions.id}"
  cloudformation_stack_name = "${var.vault_cf_stack_name}"
  security_groups           = ["${aws_security_group.vault_bastions.id}"]

  providers = {
    "aws.instance_account" = "aws.bastion"
    "aws.dns"              = "aws.dns"
    "cloudflare"           = "cloudflare"
  }
}

resource "aws_security_group_rule" "allow_vault_bastion_to_vault_loadbalancer" {
  provider                 = "aws.bastion"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.vault_bastions.id}"

  security_group_id = "${var.vault_cf_stack_outputs["VaultApplicationLoadBalancerSecurityGroup"]}"
}

module "vault_bastion_svc_dns_record" {
  source = "git@github.com:wpengine/infraform.git//modules/aws-dns-record?ref=v1.52"

  name     = "vault-bastion"
  dns_zone = "${var.service_dns_zone}"
  type     = "A"
  records  = ["${module.vault_bastion1_instance.public_ip_address}"]

  providers = {
    "aws.dns" = "aws.dns"
  }
}
