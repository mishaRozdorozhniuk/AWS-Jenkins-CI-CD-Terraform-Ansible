variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "vpc_pub_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "ami" {
  type    = string
  default = "ami-004e960cde33f9146"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "list_of_open_ports" {
  description = "A list of ports to open from anywhere (0.0.0.0/0)."
  type        = list(number)
  default     = [80, 443, 22]
}

variable "my_public_ip" {
  description = "Public IP or CIDR that is allowed to SSH into the bastion host"
  type        = string
  default     = " 31.61.246.82"
}

variable "key_name" {
  description = "AWS key pair name for EC2 instances"
  type        = string
  default     = "admin_ssh"
}

variable "public_subnets" {
  type = list(string)
  default = [
    "10.10.0.0/24",
    "10.10.1.0/24",
  ]
}

variable "private_subnets" {
  type = list(string)
  default = [
    "10.10.10.0/24",
    "10.10.11.0/24",
  ]
}

variable "max_spot_price" {
  description = "Max price of Spot-instance for Jenkins worker."
  type        = number
  default     = 0.05
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "jenkins-ansible-terraform-bucket-mykhailo-v1"
}
