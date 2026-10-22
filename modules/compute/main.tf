# -----------------------------------------------------------------------------
# main.tf (compute module)
# Builds: IAM role (SSM only), launch template, Auto Scaling Group,
# and a CPU target-tracking scaling policy.
# -----------------------------------------------------------------------------

# =============================================================================
# IAM: the instances' identity
# =============================================================================

# Trust policy: only the EC2 service may assume this role.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = merge(var.tags, { Name = "${var.name}-app-role" })
}

# The ONLY permission: let the SSM agent register so we can open a shell with
# Session Manager. This replaces SSH, so no port 22 and no key pairs exist.
# Later modules add narrow permissions here (e.g. read one secret).
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# An instance profile is the wrapper that attaches a role to an EC2 instance.
resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app-profile"
  role = aws_iam_role.app.name

  tags = merge(var.tags, { Name = "${var.name}-app-profile" })
}

# =============================================================================
# Launch template: the blueprint for every instance
# =============================================================================
locals {
  # Runs once at first boot. Starts a tiny web server on app_port and serves
  # /health so the ALB health check passes. A real app would replace this.
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail

    mkdir -p /opt/app
    echo "OK" > /opt/app/health
    echo "<h1>${var.name}: 3-tier app is running</h1>" > /opt/app/index.html

    cat > /etc/systemd/system/app.service <<'UNIT'
    [Unit]
    Description=Demo web app
    After=network.target

    [Service]
    WorkingDirectory=/opt/app
    ExecStart=/usr/bin/python3 -m http.server ${var.app_port}
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now app.service
  EOT
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  # No key_name on purpose: nobody logs in with SSH keys.
  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(local.user_data)

  # IMDSv2 only: requests need a session token, which blocks SSRF attacks
  # from stealing the instance's credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypted gp3 root volume. /dev/xvda is the root device on Amazon Linux.
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Detailed (1-minute) CloudWatch metrics, so autoscaling reacts faster.
  monitoring {
    enabled = true
  }

  # Tags for instances and volumes. Provider default_tags do NOT reach
  # instances launched by an ASG, so we set them here.
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-app-volume" })
  }

  tags = merge(var.tags, { Name = "${var.name}-app-lt" })

  # Create the new template before removing the old one.
  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Auto Scaling Group
# =============================================================================
resource "aws_autoscaling_group" "app" {
  name                = "${var.name}-app-asg"
  vpc_zone_identifier = var.private_subnet_ids # spreads instances across AZs

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # Register new instances with the ALB's target group automatically.
  target_group_arns = [var.target_group_arn]

  # "ELB" means: if the ALB health check fails, replace the instance.
  # The default "EC2" would only notice a dead machine, not a broken app.
  health_check_type         = "ELB"
  health_check_grace_period = 120 # seconds to boot before health checks count

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # When the launch template changes, replace instances gradually.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }

  # Autoscaling changes desired_capacity at runtime. Ignore it here so
  # `terraform apply` does not reset the scaler's decisions.
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Target tracking: add instances when average CPU is above the target,
# remove them when it is below. Simplest and safest scaling policy.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.cpu_target_percent
  }
}
