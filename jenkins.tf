
module "base-network" {
  source                                      = "cn-terraform/networking/aws"
  name_prefix                                 = "dojo-five"
  vpc_cidr_block                              = "192.168.0.0/16"
  availability_zones                          = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
  public_subnets_cidrs_per_availability_zone  = ["192.168.0.0/19", "192.168.32.0/19", "192.168.64.0/19", "192.168.96.0/19"]
  private_subnets_cidrs_per_availability_zone = ["192.168.128.0/19", "192.168.160.0/19", "192.168.192.0/19", "192.168.224.0/19"]
  single_nat                                  = true
}



module "jenkins" {
  source  = "./terraform-aws-jenkins/"
  /* version = "2.0.27" */
  name_prefix         = "dojo-five"
  region              = "us-east-1"
  vpc_id              = module.base-network.vpc_id
  public_subnets_ids  = module.base-network.public_subnets_ids
  private_subnets_ids = module.base-network.private_subnets_ids
}

