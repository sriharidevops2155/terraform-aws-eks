terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.98.0"
    }
  }
   backend "s3" {  #Dont save the state file in local and save the state file in below S3 bucket 
    bucket = "daws84s-remote-state-dev-sriharibandi"   
    key    = "roboshop-dev-60-acm"
    region = "us-east-1"
    encrypt = true
    use_lockfile = true # Enable native S3 locking
    #dynamodb_table = "84s-remote-state"
    # So by this here we are storing state inside S3 bucket locking with dynamo db mechanism 
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
} 