# -----------------------------------------------------------------------------
# main.tf (alb module)
# Builds: access-log bucket, ALB, target group, HTTPS listener, HTTP redirect.
# -----------------------------------------------------------------------------

# =============================================================================
# Access logs bucket
# =============================================================================
resource "aws_s3_bucket" "alb_logs" {
  bucket        = var.access_logs_bucket_name
  force_destroy = var.logs_force_destroy

  tags = merge(var.tags, { Name = var.access_logs_bucket_name })
}

# Block every form of public access. Logs must never be public.
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt at rest. ALB log delivery supports SSE-S3 (AES256) but NOT KMS keys.
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Delete old logs automatically so storage cost does not grow forever.
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {} # empty filter = applies to every object

    expiration {
      days = var.access_logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Versioning must exist before the lifecycle rule can manage old versions.
  depends_on = [aws_s3_bucket_versioning.alb_logs]
}

# The AWS-owned account that delivers ALB logs in this region.
# This is a built-in lookup table, not an API call, so it is safe offline.
data "aws_elb_service_account" "alb_logs" {}

data "aws_iam_policy_document" "alb_logs" {
  # Allow ONLY the regional ELB account to write, and ONLY under alb/.
  statement {
    sid       = "AllowELBLogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/alb/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.alb_logs.arn]
    }
  }

  # Deny any request that is not over HTTPS (encryption in transit).
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.alb_logs.arn, "${aws_s3_bucket.alb_logs.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json

  # The public access block must be in place before a policy is attached.
  depends_on = [aws_s3_bucket_public_access_block.alb_logs]
}

# =============================================================================
# The load balancer
# =============================================================================
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false # internet-facing
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  # Reject requests with malformed headers (blocks some request-smuggling attacks).
  drop_invalid_header_fields = true

  enable_deletion_protection = var.enable_deletion_protection

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = merge(var.tags, { Name = "${var.name}-alb" })

  # Log delivery is validated at creation, so the policy must exist first.
  depends_on = [aws_s3_bucket_policy.alb_logs]
}

# =============================================================================
# Target group: where the ALB sends traffic
# =============================================================================
resource "aws_lb_target_group" "app" {
  name        = "${var.name}-app-tg"
  port        = var.app_port
  protocol    = "HTTP" # TLS ends at the ALB; traffic inside the VPC is HTTP
  vpc_id      = var.vpc_id
  target_type = "instance"

  # Wait 30s (default 300s) for in-flight requests when removing an instance.
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3 # 3 passes = healthy
    unhealthy_threshold = 3 # 3 failures = removed from rotation
  }

  tags = merge(var.tags, { Name = "${var.name}-app-tg" })
}

# =============================================================================
# Listeners
# =============================================================================

# HTTPS: terminate TLS and forward to the app target group.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.tags, { Name = "${var.name}-https-listener" })
}

# HTTP: never serve content, only redirect to HTTPS with a permanent 301.
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-http-redirect" })
}