# -----------------------------------------------------------------------
# VPC — the isolated virtual network that contains all cluster resources
# -----------------------------------------------------------------------

resource "aws_vpc" "main" {               # "aws_vpc" is the Terraform resource type
                                          # "main" is our internal name — referenced as aws_vpc.main elsewhere
  cidr_block           = "10.0.0.0/16"   # IP address range for the entire VPC — allows up to 65536 addresses
  enable_dns_hostnames = true             # required by EKS — allows pods to resolve DNS names
  enable_dns_support   = true            # required by EKS — enables DNS resolution inside the VPC

  tags = {
    Name = "${var.cluster_name}-vpc"      # name tag visible in the AWS console
    # EKS uses these tags to discover the VPC when creating load balancers
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# -----------------------------------------------------------------------
# Internet Gateway — connects the VPC to the public internet
# Required for public subnets and for the NAT Gateway
# -----------------------------------------------------------------------

resource "aws_internet_gateway" "main" {  # "aws_internet_gateway" is the Terraform resource type
  vpc_id = aws_vpc.main.id                # attaches the gateway to our VPC — "aws_vpc.main.id" references the VPC above

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# -----------------------------------------------------------------------
# Public Subnets — one per availability zone
# Used by the load balancer to receive external traffic
# -----------------------------------------------------------------------

resource "aws_subnet" "public" {
  count             = 2                                         # create 2 subnets — one per availability zone for high availability
  vpc_id            = aws_vpc.main.id                          # place subnets inside our VPC
  cidr_block        = "10.0.${count.index}.0/24"               # 10.0.0.0/24 and 10.0.1.0/24 — 256 addresses each
  availability_zone = data.aws_availability_zones.available.names[count.index]  # spread across AZs
  map_public_ip_on_launch = true                               # instances in public subnets get a public IP automatically

  tags = {
    Name = "${var.cluster_name}-public-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"     # EKS needs this tag to discover subnets
    "kubernetes.io/role/elb"                    = "1"          # tells EKS to use these subnets for public load balancers
  }
}

# -----------------------------------------------------------------------
# Private Subnets — one per availability zone
# Used by Fargate pods — not directly reachable from the internet
# -----------------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = 2                                         # create 2 subnets — one per availability zone
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"          # 10.0.10.0/24 and 10.0.11.0/24 — offset to avoid overlap with public subnets
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.cluster_name}-private-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"          # tells EKS to use these subnets for internal load balancers
  }
}

# -----------------------------------------------------------------------
# NAT Gateway — allows pods in private subnets to reach the internet
# (e.g. to pull Docker images) without being publicly reachable
# Placed in the first public subnet
# -----------------------------------------------------------------------

resource "aws_eip" "nat" {               # Elastic IP — a static public IP address required by the NAT Gateway
  domain = "vpc"                         # allocate the IP for use in a VPC

  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id          # attach the Elastic IP to the NAT Gateway
  subnet_id     = aws_subnet.public[0].id # place the NAT Gateway in the first public subnet

  tags = {
    Name = "${var.cluster_name}-nat"
  }

  depends_on = [aws_internet_gateway.main] # NAT Gateway requires the Internet Gateway to exist first
}

# -----------------------------------------------------------------------
# Route Tables — define how traffic is routed within the VPC
# -----------------------------------------------------------------------

resource "aws_route_table" "public" {    # route table for public subnets
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"            # all traffic not destined for the VPC
    gateway_id = aws_internet_gateway.main.id  # route it to the internet via the Internet Gateway
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table" "private" {  # route table for private subnets
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"        # all outbound traffic from private subnets
    nat_gateway_id = aws_nat_gateway.main.id  # route through the NAT Gateway (not directly to internet)
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# associate each public subnet with the public route table
resource "aws_route_table_association" "public" {
  count          = 2                                    # one association per public subnet
  subnet_id      = aws_subnet.public[count.index].id   # reference each public subnet by index
  route_table_id = aws_route_table.public.id
}

# associate each private subnet with the private route table
resource "aws_route_table_association" "private" {
  count          = 2                                    # one association per private subnet
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------
# Data source — fetches the list of availability zones in the current region
# Used to spread subnets across AZs for high availability
# -----------------------------------------------------------------------

data "aws_availability_zones" "available" {  # "data" sources read existing AWS resources instead of creating them
  state = "available"                        # only fetch AZs that are currently available
}
