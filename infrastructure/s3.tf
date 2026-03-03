resource "aws_s3_bucket" "avatars" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = "grocerymate-avatars"
    Environment = "Dev"
  }
}