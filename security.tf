resource "aws_security_group" "jenkins_master_sg" {
  name        = "jenkins-master-sg"
  description = "Allow SSH (22) and Jenkins HTTP (8080)"
  vpc_id      = aws_vpc.mykhailo_vpc.id

   ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-master-sg" }
}

resource "aws_security_group" "jenkins_worker_sg" {
  name        = "jenkins-worker-sg"
  description = "Allow SSH (22) and Jenkins HTTP (8080)"
  vpc_id      = aws_vpc.mykhailo_vpc.id

  ingress {
    description     = "SSH from Jenkins Master SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_master_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-worker-sg" }
}
