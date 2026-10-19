# -----------------------------------------------------------------------------
# main.tf (security-groups module)
# Three security groups chained so each tier only talks to its neighbour.
#   Internet -> ALB -> App -> Database
# Rules are separate resources (not inline) to avoid circular dependencies
# and because that is the AWS-recommended approach.
# -----------------------------------------------------------------------------

# =============================================================================
# ALB security group (public tier)
# =============================================================================
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Load balancer: accepts web traffic from the internet"
  vpc_id      = var.vpc_id

  # Terraform removes the default "allow all outbound" rule from SGs it
  # creates, so this SG has NO egress until we add rules below.

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

# Inbound HTTPS from anywhere. The internet-facing door is the one place
# where 0.0.0.0/0 is expected and acceptable.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# Inbound HTTP, only so the ALB can redirect visitors to HTTPS.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet (redirected to HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# Outbound: ONLY to the app tier on the app port. Referencing the app SG by ID
# means "any instance wearing that SG", not an IP range.
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward traffic to the app tier"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

# =============================================================================
# App security group (private tier)
# =============================================================================
resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "App servers: accept traffic only from the load balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-app-sg" })
}

# Inbound: only from the ALB security group, only on the app port.
# No SSH rule: admins connect through SSM Session Manager instead.
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App traffic from the load balancer"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

# Outbound HTTPS: package updates and the SSM agent reach AWS through the NAT.
# This is the one broad egress rule; we keep it to port 443 only.
resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS out (updates, SSM) via NAT gateway"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# Outbound to the database tier on the database port only.
resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "Database traffic to the data tier"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.db.id
}

# =============================================================================
# Database security group (isolated tier)
# =============================================================================
resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Database: accept traffic only from the app tier"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-db-sg" })
}

# Inbound: only from the app SG on the database port. Nothing else can reach it.
# There are deliberately NO egress rules: a database never initiates outbound
# connections, and replies to allowed requests work because SGs are stateful.
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Database traffic from the app tier"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.app.id
}