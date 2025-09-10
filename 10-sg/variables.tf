variable "project" {
  default = "roboshop"
}

variable "environment" {
  default = "dev"
}

variable "bastion_sg_name" {
    default = "bastion"
}

variable "bastion_sg_description" {
  default = "Created sg bastion instances"
}
