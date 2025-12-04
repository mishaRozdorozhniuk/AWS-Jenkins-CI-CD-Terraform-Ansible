terraform {
  required_version = ">= 1.13.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-s3-22"
    region = "eu-central-1"
    key    = "terraform-jenkins-ansible/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}
