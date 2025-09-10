module "vpc" {
    source = "git::https://github.com/sriharidevops2155/terraform-aws-vpc.git?ref=main"
    project = var.project
    environment = var.environment
    public_subnet_cidrs = var.public_subnet_cidrs
    private_subnet_cidrs = var.private_subnet_cidrs
    data_base_subnet_cidrs = var.data_base_subnet_cidrs
    is_peering_required = true
}

/* output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}  */