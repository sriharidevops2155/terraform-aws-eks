resource "aws_ssm_parameter" "ingress_alb_listner_arn" {
  name  = "/${var.project}/${var.environment}/ingress_alb_listner_arn"
  type  = "String"
  value = aws_lb_listener.frontend_alb.arn
  overwrite = true
}