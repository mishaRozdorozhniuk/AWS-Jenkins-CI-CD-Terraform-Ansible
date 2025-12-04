resource "aws_vpc" "mykhailo_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "mykhailo_vpc"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "jenkins_master_pub_subnet" {
  vpc_id     = aws_vpc.mykhailo_vpc.id
  cidr_block = var.public_subnets[0]
  tags = {
    Name = "jenkins_master_pub_subnet"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "jenkins_worker_priv_subnet" {
  vpc_id     = aws_vpc.mykhailo_vpc.id
  cidr_block = var.private_subnets[0]
  tags = {
    Name = "jenkins_master_priv_subnet"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "nat_gw_eip" {
  domain = "vpc"
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.mykhailo_vpc.id
}

resource "aws_nat_gateway" "main_ngw" {
  subnet_id     = aws_subnet.jenkins_master_pub_subnet.id
  allocation_id = aws_eip.nat_gw_eip.id
}

// Routes

// pub
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mykhailo_vpc.id
}

resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.jenkins_master_pub_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

//priv
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.mykhailo_vpc.id
}

resource "aws_route" "private_internet_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main_ngw.id
}

resource "aws_route_table_association" "private_rt_association" {
  subnet_id      = aws_subnet.jenkins_worker_priv_subnet.id
  route_table_id = aws_route_table.private_rt.id
}
