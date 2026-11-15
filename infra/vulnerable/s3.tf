resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "public_assets" {
  bucket        = "${local.prefix}-public-assets-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "placeholder" {
  bucket       = aws_s3_bucket.public_assets.id
  key          = "placeholder.txt"
  content      = "Datadog Cloud Security demo placeholder. Contains no data.\n"
  content_type = "text/plain"
}

data "aws_iam_policy_document" "public_assets" {
  statement {
    sid       = "PublicReadPlaceholder"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.public_assets.arn}/${aws_s3_object.placeholder.key}"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id
  policy = data.aws_iam_policy_document.public_assets.json

  depends_on = [aws_s3_bucket_public_access_block.public_assets]
}
