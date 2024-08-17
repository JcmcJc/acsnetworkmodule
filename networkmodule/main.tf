# Terraform Config file (main.tf). This has provider block (AWS) and config for provisioning one EC2 instance resource.  

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27"
    }
  }

  required_version = ">=0.14"
}
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Define tags locally
locals {
  default_tags = merge(var.default_tags, { "env" = var.env })
}

# Create a new VPC 
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-vpc"
    }
  )
}

#############
###Subnets###
#############

# Add provisioning of the public subnetin the default VPC
resource "aws_subnet" "public" {
  count             = length(var.public_cidr_blocks)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-public-subnet-${count.index+1}"
    }
  )
}
# Add provisioning of the private subnetin the default VPC
resource "aws_subnet" "private" {
  count             = length(var.private_cidr_blocks)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-private-subnet-${count.index+1}"
    }
  )
}

#######################
###IGW, NGW, and EIP###
#######################

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-igw"
    }
  )
}
#Create elastic ips for nat gateways
resource "aws_eip" "static_eip" {
  #instance = aws_instance.acs73026.id
  #count = length(aws_subnet.public[*].id)
  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-eip"
    }
  )
}

#Create nat gateway in public subnet 1
resource "aws_nat_gateway" "nat" {
  #count          = length(aws_subnet.public[*].id)
  connectivity_type = "public"
  allocation_id = aws_eip.static_eip.id
  subnet_id         = aws_subnet.public[0].id
   tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-ngw"
    }
  )
}

##############################
###Route table associations###
##############################

# Route table to route add default gateway pointing to Internet Gateway (IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.prefix}-route-public-subnets"
  }
}

# Route table pointing to public subnet 1 nat gateway for private subnet 1
resource "aws_route_table" "private0" {
  vpc_id         = aws_vpc.main.id
  route {
    cidr_block  = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.prefix}-route-private-subnet1"
  }
}
# Route table pointing to nothing for private subnet 2
resource "aws_route_table" "private1" {
  vpc_id         = aws_vpc.main.id
  tags = {
    Name = "${var.prefix}-route-private-subnet2"
  }
}

# Associate subnets with the custom route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public[*].id)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}
#Route for Nat gateway to private subnet 1 ONLY
resource "aws_route_table_association" "private0" {
  #count          = length(aws_subnet.private[*].id)
  route_table_id = aws_route_table.private0.id
  subnet_id      = aws_subnet.private[0].id
}
#Route for private subnet 2 which doesnt point to anything
resource "aws_route_table_association" "private1" {
  #count          = length(aws_subnet.private[*].id)
  route_table_id = aws_route_table.private1.id
  subnet_id      = aws_subnet.private[1].id
}


