# ---------------------------------------------------------------------------
# VPC — created by default. Set create_vpc = false and supply vpc_id +
# subnet_ids to bring your own (e.g. when your AWS permissions don't allow
# VPC creation — see the README permissions section).
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  count = var.create_vpc ? 1 : 0
  state = "available"
}

locals {
  az_names = var.create_vpc ? slice(data.aws_availability_zones.available[0].names, 0, var.vpc_az_count) : []

  # /16 split into /20 subnets: private get the first N, public the next N.
  private_subnet_cidrs = [for i in range(var.vpc_az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnet_cidrs  = [for i in range(var.vpc_az_count) : cidrsubnet(var.vpc_cidr, 4, i + var.vpc_az_count)]

  # Resolved values the rest of the module consumes.
  eks_vpc_id     = var.create_vpc ? aws_vpc.this[0].id : var.vpc_id
  eks_subnet_ids = var.create_vpc ? aws_subnet.private[*].id : var.subnet_ids
}

resource "aws_vpc" "this" {
  count                = var.create_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.cluster_name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = merge(var.tags, { Name = "${var.cluster_name}-igw" })
}

# Public subnets — host the NAT gateway only (egress path for private subnets).
resource "aws_subnet" "public" {
  count                   = var.create_vpc ? var.vpc_az_count : 0
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-${count.index + 1}"
  })
}

# Private subnets — where EKS Auto Mode places nodes.
resource "aws_subnet" "private" {
  count             = var.create_vpc ? var.vpc_az_count : 0
  vpc_id            = aws_vpc.this[0].id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-private-${count.index + 1}"
  })
}

# Single NAT gateway by default (cost-friendly for a demo). Set
# single_nat_gateway = false for one-per-AZ high availability.
resource "aws_eip" "nat" {
  count  = var.create_vpc ? (var.single_nat_gateway ? 1 : var.vpc_az_count) : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.cluster_name}-nat-${count.index + 1}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.create_vpc ? (var.single_nat_gateway ? 1 : var.vpc_az_count) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.cluster_name}-nat-${count.index + 1}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = var.create_vpc ? var.vpc_az_count : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count  = var.create_vpc ? (var.single_nat_gateway ? 1 : var.vpc_az_count) : 0
  vpc_id = aws_vpc.this[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-private-rt-${count.index + 1}" })
}

resource "aws_route_table_association" "private" {
  count          = var.create_vpc ? var.vpc_az_count : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
