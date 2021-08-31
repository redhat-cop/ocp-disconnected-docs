terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.53.0"
    }
  }
}

provider "aws" {
  region = "us-gov-east-1"
}