# -----------------------------------------------------------------------------
# main.tf (vpc module)
# Builds: VPC, IGW, 3 subnet tiers, route tables, NAT gateways,
# a locked-down default SG, and flow logs.
# -----------------------------------------------------------------------------

locals {
  # One NAT per AZ for prod, a single NAT for dev.
  nat_count = var.single_nat_gateway ? 1 : length(var.azs)
}

# --- The VPC -----------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Both are required so instances and endpoints can resolve DNS names.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

# --- Lock down the default security group -------------------------------------
# Every VPC ships with a default SG that allows all traffic between its members.
# Declaring it with NO rules removes all access. We create our own SGs instead.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-default-sg-locked" })
}

# --- Internet Gateway (public tier's door to the internet) ---------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

# --- Subnets -------------------------------------------------------------------
# count loops once per AZ. Index 0 pairs with azs[0], index 1 with azs[1].

resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # Public IPs are NOT auto-assigned. The ALB and NAT gateways get their own
  # addresses, so nothing else in this tier needs one (checkov flags this).
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${var.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-private-${var.azs[count.index]}"
    Tier = "app"
  })
}

resource "aws_subnet" "database" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-database-${var.azs[count.index]}"
    Tier = "database"
  })
}

# --- NAT gateways ----------------------------------------------------------------
# A NAT gateway needs a static public IP (Elastic IP) and lives in a PUBLIC subnet.
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index + 1}" })

  # The EIP needs the IGW to exist first, so make that dependency explicit.
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${count.index + 1}" })

  depends_on = [aws_internet_gateway.this]
}

# --- Route tables ------------------------------------------------------------------

# Public: one table, default route (0.0.0.0/0) goes to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private: one table PER AZ, so each AZ can route to its own NAT in prod.
# element() wraps around, so with a single NAT every AZ uses NAT #1.
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index % local.nat_count].id
  }

  tags = merge(var.tags, { Name = "${var.name}-private-rt-${var.azs[count.index]}" })
}

resource "aws_route_table_association" "private" {
  count = length(var.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database: ONE table with NO internet route. Only the implicit local route
# (traffic inside the VPC) exists. RDS can talk to the app tier, nothing else.
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-database-rt" })
}

resource "aws_route_table_association" "database" {
  count = length(var.azs)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# --- VPC Flow Logs -------------------------------------------------------------------
# Records every accepted/rejected connection: essential for security and debugging.

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days

  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}

# Trust policy: only the VPC Flow Logs service may assume this role.
data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

# Permission policy: least privilege. It may write ONLY to this one log group.
data "aws_iam_policy_document" "flow_logs_write" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json

  tags = merge(var.tags, { Name = "${var.name}-vpc-flow-logs-role" })
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "write-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_write.json
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL" # accepted AND rejected traffic
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn    = aws_iam_role.flow_logs.arn

  tags = merge(var.tags, { Name = "${var.name}-flow-log" })
}