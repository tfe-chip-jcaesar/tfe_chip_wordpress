output "us_vpc_data" {
  value = {
    "vpc_id" = module.us_vpc.vpc_id
    "cidr"   = module.us_vpc.cidr
    "region" = "us-west-1"
  }
}

output "eu_vpc_data" {
  value = {
    "vpc_id" = module.eu_vpc.vpc_id
    "cidr"   = module.eu_vpc.cidr
    "region" = "eu-central-1"
  }
}
