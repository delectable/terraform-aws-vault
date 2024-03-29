############################
## Environment #############
############################

variable "env" {
  type        = "string"
  description = "The environment that Vault will be run in"
}

variable "region" {
  type        = "string"
  description = "The AWS region to use"
}

variable "dr_region" {
  type        = "string"
  description = "The AWS Region to use for disaster recovery"
}

variable "aws_account_id" {
  type        = "string"
  description = "The account id of the AWS account to place resources in"
}

variable "tags" {
  type        = "map"
  description = "A map of tags to apply to all resources"
}

variable "tags_asg" {
  type        = "list"
  description = "A list of maps of tags to apply to the autoscaling group"
}

############################
## Networking ##############
############################

variable "vault_dns_address" {
  type        = "string"
  description = "The DNS address that vault will be accessible at"
}

variable "vpc_id" {
  type        = "string"
  description = "The ID of the VPC to use"
}

variable "alb_subnets" {
  type        = "list"
  description = "A list of subnets to launch the ALB in"
}

variable "ec2_subnets" {
  type        = "list"
  description = "A list of subnets to launch the EC2 instances in"
}

variable "alb_allowed_ingress_cidrs" {
  type        = "list"
  description = "A list of CIDRs to allow traffic into the ALB"
}

variable "alb_allowed_egress_cidrs" {
  type        = "list"
  description = "A list of CIDRS to allow traffic out from ALB. This should match the subnet CIDRs that the Vault EC2 instances are launched in"
}

############################
## ALB #####################
############################

variable "alb_certificate_arn" {
  type        = "string"
  description = "The ARN of the certificate to use on the ALB"
}

variable "alb_internal" {
  type        = "string"
  description = "true for an internal-only Vault instance, false otherwise"
}

############################
## EC2 #####################
############################

variable "ami_id" {
  type        = "string"
  description = "The ID of the AMI to use to launch Vault"
}

variable "instance_type" {
  type        = "string"
  description = "The type of instance to launch vault on"
}

variable "ssh_key_name" {
  type        = "string"
  description = "The name of the ssh key to use for the EC2 instance"
}

variable "asg_min_size" {
  type        = "string"
  description = "Minimum number of instances in the ASG"
}

variable "asg_max_size" {
  type        = "string"
  description = "Maximum number of instances in the ASG"
}

variable "asg_desired_capacity" {
  type        = "string"
  description = "Desired number of instances in the ASG"
}

############################
## S3 ######################
############################

variable "vault_resources_bucket_name" {
  type        = "string"
  description = "The name of the vault resources bucket"
}

variable "vault_data_bucket_name" {
  type        = "string"
  description = "The name of the vault data bucket"
}

############################
## DynamoDB ################
############################

variable "dynamodb_table_name" {
  type        = "string"
  description = "The name of the dynamodb table that vault will create to coordinate HA"
}

