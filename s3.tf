resource "aws_s3_bucket" "my_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = "Jenkins Ansible Terraform Bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_versioning" "my_bucket_versioning" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
