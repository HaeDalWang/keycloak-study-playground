variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.10.0.0/16"
}

variable "instance_type" {
  description = "Default instance type for linux"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 Key Pair"
  type        = string
  default     = "saltware"
}
