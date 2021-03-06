data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "terraform_states" {
  bucket = "${var.s3_states_bucket_name}-${data.aws_caller_identity.current.account_id}"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = merge(var.tags)
}

resource "aws_s3_bucket_policy" "terraform_states" {
  bucket = aws_s3_bucket.terraform_states.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "MustUseHttps",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "*",
            "Resource": [
                "${aws_s3_bucket.terraform_states.arn}/*",
                "${aws_s3_bucket.terraform_states.arn}"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        },
        {
            "Sid": "EncryptedAtRest",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:PutObject",
            "Resource": [
                "${aws_s3_bucket.terraform_states.arn}/*",
                "${aws_s3_bucket.terraform_states.arn}"
            ],
            "Condition": {
                "StringNotEquals": {
                    "s3:x-amz-server-side-encryption": "AES256"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_dynamodb_table" "terraform_lock_table" {
  name           = var.table_name
  read_capacity  = "1"
  write_capacity = "1"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(var.tags, map("Name", var.table_name))
}
