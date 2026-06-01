variable "vpc_cidr" {
  description = "VPC 대역대"
  type        = string
  default     = "10.112.0.0/16"
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 키페어 이름 (SSM 사용 시 null 가능)"
  type        = string
  default     = "saltware"
}
