# -----------------------------------------------------------------------------
# Calculate which AZs to build subnets within
# -----------------------------------------------------------------------------

data "aws_availability_zones" "us_azs" {
  provider = aws.us-west-1
  state    = "available"
}

data "aws_availability_zones" "eu_azs" {
  provider = aws.eu-central-1
  state    = "available"
}

locals {
  us_az_suffixes = [for az in data.aws_availability_zones.us_azs.names : trimprefix(az, "us-west-1")]
  us_azs         = slice(local.us_az_suffixes, 0, var.num_azs > length(local.us_az_suffixes) ? length(local.us_az_suffixes) : var.num_azs)
  eu_az_suffixes = [for az in data.aws_availability_zones.eu_azs.names : trimprefix(az, "eu-central-1")]
  eu_azs         = slice(local.eu_az_suffixes, 0, var.num_azs > length(local.eu_az_suffixes) ? length(local.eu_az_suffixes) : var.num_azs)

  common_tags = { "Owner" = "Jamie Caesar", "Company" = "Spacely Sprockets", "BU" = "Wordpress" }
}

# -----------------------------------------------------------------------------
# US West 1 VPC
# -----------------------------------------------------------------------------

module "us_vpc" {
  source  = "tfe.aws.shadowmonkey.com/spacelysprockets/ss_vpc/aws"
  version = "0.2.1"

  cidr_block = "10.13.0.0/16"
  vpc_name   = "us_wordpress"
  tags       = local.common_tags
  azs        = local.us_azs

  providers = {
    aws = aws.us-west-1
  }
}

# -----------------------------------------------------------------------------
# EU Central 1 VPC
# -----------------------------------------------------------------------------

module "eu_vpc" {
  source  = "tfe.aws.shadowmonkey.com/spacelysprockets/ss_vpc/aws"
  version = "0.2.1"

  cidr_block = "10.23.0.0/16"
  vpc_name   = "eu_wordpress"
  tags       = local.common_tags
  azs        = local.eu_azs

  providers = {
    aws = aws.eu-central-1
  }
}

# -----------------------------------------------------------------------------
# Admin VPC Routes (Peering defined on Admin side)
# -----------------------------------------------------------------------------

data "terraform_remote_state" "admin" {
  backend = "remote"

  config = {
    hostname     = "tfe.aws.shadowmonkey.com"
    organization = "spacelysprockets"
    workspaces = {
      name = "tfe_chip_admin"
    }
  }
}

resource "aws_route" "us-admin" {
  provider = aws.us-west-1
  for_each = toset(module.us_vpc.route_tables)

  route_table_id            = each.value
  destination_cidr_block    = data.terraform_remote_state.admin.outputs.us_vpc_data.cidr
  vpc_peering_connection_id = data.terraform_remote_state.admin.outputs.wp_us_pcx
}

resource "aws_route" "eu-admin" {
  provider = aws.eu-central-1
  for_each = toset(module.eu_vpc.route_tables)

  route_table_id            = each.value
  destination_cidr_block    = data.terraform_remote_state.admin.outputs.eu_vpc_data.cidr
  vpc_peering_connection_id = data.terraform_remote_state.admin.outputs.wp_eu_pcx
}

