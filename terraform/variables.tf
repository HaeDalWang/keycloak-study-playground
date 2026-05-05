variable "vpc_cidr" {
  description = "VPC 대역대"
  type        = string
}

variable "instance_type" {
  description = "Keycloak EC2 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 SSH 키페어 이름 (SSM Session Manager 사용 시 null 가능)"
  type        = string
  default     = null
}

variable "test_user_password" {
  description = "테스트 사용자 초기 비밀번호 (첫 로그인 시 변경 강제)"
  type        = string
  sensitive   = true
  default     = "Change1234!"
}