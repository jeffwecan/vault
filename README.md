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

## Deployment

For the most part, the included Terraform configuration file and associated "terraform" Jenkins shared var handles most
of the deployment of this repository automatically. One notable exception is the Vault VPC to corporate Heroku private
space peering connection.

### Heroku Private Spaces

Since Heroku currently offers no public API routes for managing peering connections between customer-manged VPCs and
their private space offering, some manual steps are required before and after applying Terraform configuration that
configures those type of connections. In particular, the "corporate" Terraform configuration has several requirements
along those lines. The general steps are:

1. Lookup the Heroku-specific values required for a subset of our Terraform variables.
2. Retrieve the VPC peering connection ID from the output of a subsequent `terraform apply`.
3. Accept the peering connection on the Heroku private spaces side of things.

#### Discovering Heroku-specific Private Space Peering Values

The three variables listed in the following table are needed to initiate the VPC peering connection. These can all be
found via the `heroku spaces:peering:info --json --space "$SPACE_NAME"` CLI command.

|Terraform Variable Name|Heroku Peering Info Output Field (json)|
|-----------------------|---------------------------------------|
|heroku_wpengine_corporate_space_peer_owner|aws_account_id|
|heroku_wpengine_corporate_space_vpc_id|vpc_id|
|heroku_wpengine_corporate_space_dyno_cidrs|dyno_cidr_blocks|

#### Retrieve the VPC Peering Connection ID

Follow a `terraform apply` run, the `heroku_space_peering_pcx_id` output variable contains the ID in question. E.g.:

```Text
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
Releasing state lock. This may take a few moments...

Outputs:

allow_cm_to_vault_loadbalancer_id = sgrule-2303266657
[...]
heroku_space_peering_pcx_id = pcx-efc26587
[...]
```

In the above example, this would be `pcx-efc26587`.

#### Accept the VPC Peering Connection

With the VPC peering connection ID, run the following Heroku CLI command to accept and configure the peering connection:

`heroku spaces:peerings:accept pcx-efc26587 --space "$SPACE_NAME"`

Following the successfully execution of that command, the `spaces:peering` CLI command can be used to verify the connection
is in the expected state:

```Text
$ heroku spaces:peerings wpengine-corporate
=== wpengine-corporate Peerings
PCX ID        Type              CIDR Blocks     Status  VPC ID        AWS Account ID  Expires
────────────  ────────────────  ──────────────  ──────  ────────────  ──────────────  ───────
pcx-efc26587  customer-managed  172.30.84.0/24  active  vpc-d762c8af  770273818880
```
