data "aws_ami" "rhel" {
  owners = ["973714476881"]
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-9-DevOps-Practice"]
  }
} 

data "aws_ssm_parameter" "bastion_id" {
  name = "/${var.project}/${var.environment}/bastion_sg_id"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/${var.project}/${var.environment}/public_subnet_ids"
}

/* output "ami_id" {
   value = data.aws_ami.joindevops.id
}
 */