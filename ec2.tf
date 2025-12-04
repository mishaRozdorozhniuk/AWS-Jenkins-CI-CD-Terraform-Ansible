resource "aws_instance" "jenkins_master" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.jenkins_master_pub_subnet.id

  associate_public_ip_address = true

  security_groups = [aws_security_group.jenkins_master_sg.id]

  user_data = templatefile("${path.module}/user-data.sh", {
    ssh_key_content = file("/Users/mykhailo/Desktop/admin_ssh.pub")
  })

  key_name = aws_key_pair.admin_key.key_name

  tags = {
    Name = "jenkins_master"
  }
}

resource "aws_instance" "jenkins_worker" {
  ami           = var.ami
  instance_type = var.instance_type

  subnet_id = aws_subnet.jenkins_worker_priv_subnet.id

  security_groups = [aws_security_group.jenkins_worker_sg.id]

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = var.max_spot_price
    }
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    ssh_key_content = file("/Users/mykhailo/Desktop/admin_ssh.pub")
  })

  key_name = aws_key_pair.admin_key.key_name

  tags = {
    Name = "jenkins_worker"
  }
}

// pub key

resource "aws_key_pair" "admin_key" {
  key_name   = var.key_name
  public_key = file("/Users/mykhailo/Desktop/admin_ssh.pub")
}
