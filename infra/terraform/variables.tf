variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_name" {
  type    = string
  default = "private-members"
}
variable "environment" {
  type        = string
  description = "staging | production"
}
variable "domain_name" {
  type        = string
  description = "Apex domain, e.g. example.com"
}
variable "app_subdomain" {
  type    = string
  default = "app"
}
variable "admin_subdomain" {
  type    = string
  default = "admin"
}
variable "api_subdomain" {
  type    = string
  default = "api"
}
variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.small"
}
variable "db_multi_az" {
  type    = bool
  default = false
}
variable "eb_instance_type" {
  type    = string
  default = "t4g.small"
}
variable "alert_email" {
  type = string
}
variable "budget_usd" {
  type    = number
  default = 200
}
variable "github_org" {
  type = string
}
variable "github_repo" {
  type = string
}
