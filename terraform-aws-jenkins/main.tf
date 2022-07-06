#------------------------------------------------------------------------------
# AWS Cloudwatch Logs
#------------------------------------------------------------------------------
module "aws_cw_logs" {
  source  = "cn-terraform/cloudwatch-logs/aws"
  version = "1.0.11"

  create_kms_key              = var.create_kms_key
  log_group_kms_key_id        = var.log_group_kms_key_id
  log_group_retention_in_days = var.log_group_retention_in_days
  logs_path                   = "/ecs/service/${var.name_prefix}-jenkins-master"
}

#------------------------------------------------------------------------------
# Locals
#------------------------------------------------------------------------------
locals {
  container_name = "${var.name_prefix}-jenkins"
  healthcheck = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080 || exit 1"]
    retries     = 3
    timeout     = 5
    interval    = 30
    startPeriod = 120
  }
  td_port_mappings = [
    {
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    },
    {
      containerPort = 2049
      hostPort      = 2049
      protocol      = "tcp"
    },
    {
      containerPort = 50000
      hostPort      = 50000
      protocol      = "tcp"
    }
  ]
  service_http_ports = {
    ui = {
      listener_port     = 80
      target_group_port = 8080
    },
    workers = {
      listener_port     = 50000
      target_group_port = 50000
    }
  }
  service_https_ports = {}
}

#------------------------------------------------------------------------------
# ECS Cluster
#------------------------------------------------------------------------------
module "ecs-cluster" {
  source  = "cn-terraform/ecs-cluster/aws"
  version = "1.0.10"
  # source  = "../terraform-aws-ecs-cluster"

  name = "${var.name_prefix}-jenkins"
}

#------------------------------------------------------------------------------
# ECS Task Definition
#------------------------------------------------------------------------------
module "td" {
  source  = "cn-terraform/ecs-fargate-task-definition/aws"
  version = "1.0.29"
  # source  = "../terraform-aws-ecs-fargate-task-definition"

  name_prefix      = "${var.name_prefix}-jenkins"
  container_name   = local.container_name
  container_image  = "cnservices/jenkins-master"
  container_cpu    = 2048 # 2 vCPU - https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-task-defs
  container_memory = 4096 # 4 GB  - https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-task-defs
  port_mappings    = local.td_port_mappings
  healthcheck      = local.healthcheck
  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.region
      "awslogs-group"         = module.aws_cw_logs.logs_path
      "awslogs-stream-prefix" = "ecs"
    }
    secretOptions = null
  }
}

#------------------------------------------------------------------------------
# ECS Service
#------------------------------------------------------------------------------
module "ecs-fargate-service" {
  source  = "cn-terraform/ecs-fargate-service/aws"
  version = "2.0.31"
  # source  = "../terraform-aws-ecs-fargate-service"

  name_prefix                       = "${var.name_prefix}-jenkins"
  vpc_id                            = var.vpc_id
  ecs_cluster_arn                   = module.ecs-cluster.aws_ecs_cluster_cluster_arn
  health_check_grace_period_seconds = 120
  task_definition_arn               = module.td.aws_ecs_task_definition_td_arn
  public_subnets                    = var.public_subnets_ids
  private_subnets                   = var.private_subnets_ids
  container_name                    = local.container_name
  enable_autoscaling                = var.enable_autoscaling
  ecs_cluster_name                  = module.ecs-cluster.aws_ecs_cluster_cluster_name

  lb_http_ports  = local.service_http_ports
  lb_https_ports = local.service_https_ports
}
