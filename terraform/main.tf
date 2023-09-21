terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source             = "./vpc"
  name               = var.name
  cidr               = var.cidr
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  availability_zones = var.availability_zones
}

module "security_groups" {
  source         = "./security-groups"
  name           = var.name
  vpc_id         = module.vpc.id
  container_port = var.container_port
}

module "ecr" {
  source          = "./ecr"
  name            = var.name
  name_suffix     = var.name_suffix
}

module "ecs" {
  source                      = "./ecs"
  name                        = var.name
  name_suffix                 = var.name_suffix
  region                      = var.region
  subnets                     = module.vpc.private_subnets
  ecs_service_security_groups = [module.security_groups.ecs_tasks]
  container_port              = var.container_port
  container_cpu               = var.container_cpu
  container_memory            = var.container_memory
  ecr_repository_urls         = module.ecr.aws_ecr_repository_urls
  service_desired_count       = var.service_desired_count
}

module "lambda" {
  source                             = "./lambda"
  name                               = var.name
  region                             = var.region
  quickstart_s3_bucket               = "${var.quickstart_s3_bucket}-${var.region}"
  event_filtering_function_name      = "${var.name}-${var.event_filtering_function_name}"
  event_filtering_s3_key             = var.event_filtering_s3_key
  soci_index_generator_function_name = "${var.name}-${var.soci_index_generator_function_name}"
  soci_index_generator_s3_key        = var.soci_index_generator_s3_key
  soci_image_filter                  = var.soci_image_filter
}
