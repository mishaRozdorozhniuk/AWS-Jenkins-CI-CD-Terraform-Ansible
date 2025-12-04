output "jenkins_master_public_ip" {
  value = aws_instance.jenkins_master.public_ip
}

output "jenkins_master_private_ip" {
  value = aws_instance.jenkins_master.private_ip
}

output "vpc_id" {
  value = aws_vpc.mykhailo_vpc.id
}

output "jenkins_master_sg_id" {
  value = aws_security_group.jenkins_master_sg.id
}
