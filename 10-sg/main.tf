module "ingress_alb" {
    #source = "../../terraform-aws-sg"
    source = "git::https://github.com/sriharidevops2155/terraform-aws-sg.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "ingress_alb_sg"
    sg_description = "Security group for ingress_alb"
    vpc_id = local.vpc_id
}

module "bastion" {
    #source = "../../terraform-aws-sg"
    source = "git::https://github.com/sriharidevops2155/terraform-aws-sg.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = var.bastion_sg_name
    sg_description = var.bastion_sg_description
    vpc_id = local.vpc_id
}

module "vpn" {
    #source = "../../terraform-aws-sg"
    source = "git::https://github.com/sriharidevops2155/terraform-aws-sg.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "vpn_sg"
    sg_description = "Security group for VPN"
    vpc_id = local.vpc_id
}

module "eks_control_plane" {
    #source = "../../terraform-aws-sg"
    source = "git::https://github.com/sriharidevops2155/terraform-aws-sg.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "eks_control_plane"
    sg_description = "Security group for eks_control_plane"
    vpc_id = local.vpc_id
}

module "eks_node" {
    #source = "../../terraform-aws-sg"
    source = "git::https://github.com/sriharidevops2155/terraform-aws-sg.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "eks_node"
    sg_description = "Security group for eks_node"
    vpc_id = local.vpc_id
}

resource "aws_security_group_rule" "ingress_alb_https" {#frontend ALB is accepting connections from https
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = module.ingress_alb.sg_id
} 

resource "aws_security_group_rule" "bastion_laptop" {#Bastion laptop is accepting connections from laptops
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.bastion.sg_id
}

#VPN ports 22, 443 , 1194 , 943
resource "aws_security_group_rule" "vpn_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = module.vpn.sg_id
}

resource "aws_security_group_rule" "vpn_hhtps" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = module.vpn.sg_id
}

resource "aws_security_group_rule" "vpn_1194" {
  type              = "ingress"
  from_port         = 1194
  to_port           = 1194
  protocol          = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = module.vpn.sg_id
}

resource "aws_security_group_rule" "vpn_943" {
  type              = "ingress"
  from_port         = 943
  to_port           = 943
  protocol          = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = module.vpn.sg_id
}

resource "aws_security_group_rule" "eks_control_plane_eks_node" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  source_security_group_id = module.eks_node.sg_id 
  security_group_id = module.eks_control_plane.sg_id
}

resource "aws_security_group_rule" "eks_control_plane_bastion" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  source_security_group_id = module.bastion.sg_id 
  security_group_id = module.eks_control_plane.sg_id
}

resource "aws_security_group_rule" "eks_node_bastion" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = module.bastion.sg_id 
  security_group_id = module.eks_control_plane.sg_id
}

resource "aws_security_group_rule" "eks_node_vpc" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks = ["10.0.0.0/16"]
  security_group_id = module.eks_node.sg_id
}