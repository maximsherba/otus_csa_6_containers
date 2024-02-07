terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.3"
    }
	docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }	
  }
}

provider "aws" {
  region  = "eu-west-3"
  profile = var.aws_profile
}
