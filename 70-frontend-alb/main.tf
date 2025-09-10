module "ingress_alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "9.16.0"
  internal = false        # Mean internet can access this Loadbalancer i.e the resource is public (internet-facing)
  name    = "${var.project}-${var.environment}-ingress-alb"  #roboshop-dev-ingress-alb
  vpc_id  = local.vpc_id
  subnets = local.public_subnet_ids
  create_security_group = false
  security_groups = [local.ingress_alb_sg_id]
  enable_deletion_protection = false

  tags = merge(
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-ingress-alb"
    }
  )
}

resource "aws_lb_listener" "ingress_alb" {
  load_balancer_arn = module.ingress_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.acm_certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1>Hello, I am from ingress ALB using HTTPS</h1>"
      status_code  = "200"
    }
  }
}  

resource "aws_route53_record" "ingress_alb" {
  zone_id = var.zone_id
  name    = "${var.environment}.${var.zone_name}" #.daws84s.cloud
  type    = "A"

  alias {
    name                   = module.ingress_alb.dns_name
    zone_id                = module.ingress_alb.zone_id #This is the ZONE ID of ALB
    evaluate_target_health = true
  }
}