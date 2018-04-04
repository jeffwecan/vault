# vault

WP Engine's [Vault](https://vaultproject.io/) networking, and other auxiliary configuration/resource, management and
 CI/CD pipeline.

## Overview

This repository leverages Terraform to:

- Peer AWS VPC-housed resources to the AWS VPC containing our vault service.
- Connect GCP network / resources via VPN tunnels to the AWS VPC containing our vault service.
- Set DNS records for Vault ingress points. E.g., the internally-facing EC2 Application Load Balancer that has our
 vault nodes as a target.

## Architecture

For information on all architectural decisions, click the links below.

- [Recording Architecture Decisions](./docs/adr/0001-record-architecture-decisions.md)

## Development

To validate terraform modifications locally, the following Makefile jobs can be used:

- `make terraform-validate`
- `make terraform-plan`

Those jobs will run terraform commands against all accounts / environments. To target a specific account, tack on the
 environment's directory name to the job name. E.g.: `make terraform-plan-development`.
