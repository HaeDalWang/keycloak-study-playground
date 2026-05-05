# EC2가 SSM Session Manager로 접근 가능하도록 IAM Role 부여
resource "aws_iam_role" "keycloak_ec2" {
  name = "${local.project}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.project}-ec2-role" }
}

# SSM Session Manager 접속에 필요한 AWS 관리형 정책
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.keycloak_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Role을 EC2에 붙이려면 Instance Profile로 감싸야 함
resource "aws_iam_instance_profile" "keycloak_ec2" {
  name = "${local.project}-ec2-profile"
  role = aws_iam_role.keycloak_ec2.name
}
