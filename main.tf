terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
  }

  required_version = ">= 1.2.0"

}

provider "aws" {
  region = "eu-west-2"
}

# Create a VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_block
  enable_dns_hostnames = true
  enable_dns_support = true
}

# Create the internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.eks_vpc.id
}

# Create the public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id
}

# Create the private route tables
resource "aws_route_table" "private_route_table_01" {
  vpc_id = aws_vpc.eks_vpc.id
}
resource "aws_route_table" "private_route_table_02" {
  vpc_id = aws_vpc.eks_vpc.id
}

# Create the public route
resource "aws_route" "public_route" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id
}

# Create the private routes
resource "aws_route" "private_route_01" {
  route_table_id = aws_route_table.private_route_table_01.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway_01.id
}
resource "aws_route" "private_route_02" {
  route_table_id = aws_route_table.private_route_table_02.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway_02.id
}

# Create the NAT gateways
resource "aws_nat_gateway" "nat_gateway_01" {
  allocation_id = aws_eip.nat_gateway_eip_01.id
  subnet_id = aws_subnet.public_subnet_01.id
}
resource "aws_nat_gateway" "nat_gateway_02" {
  allocation_id = aws_eip.nat_gateway_eip_02.id
  subnet_id     = aws_subnet.public_subnet_02.id
}

# Create the elastic IPs for the NAT gateways
resource "aws_eip" "nat_gateway_eip_01" {
  domain = "vpc"
}
resource "aws_eip" "nat_gateway_eip_02" {
  domain = "vpc"
}

# Create the public subnets
resource "aws_subnet" "public_subnet_01" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public_subnet_01_block
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2a"
}
resource "aws_subnet" "public_subnet_02" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public_subnet_02_block
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2b"
}

# Create the private subnets
resource "aws_subnet" "private_subnet_01" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.private_subnet_01_block
  map_public_ip_on_launch = false
  availability_zone       = "eu-west-2a"
}
resource "aws_subnet" "private_subnet_02" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.private_subnet_02_block
  map_public_ip_on_launch = false
  availability_zone       = "eu-west-2b"
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public_subnet_01_association" {
  subnet_id      = aws_subnet.public_subnet_01.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_02_association" {
  subnet_id      = aws_subnet.public_subnet_02.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate private subnets with the private route tables
resource "aws_route_table_association" "private_subnet_01_association" {
  subnet_id      = aws_subnet.private_subnet_01.id
  route_table_id = aws_route_table.private_route_table_01.id
}

resource "aws_route_table_association" "private_subnet_02_association" {
  subnet_id      = aws_subnet.private_subnet_02.id
  route_table_id = aws_route_table.private_route_table_02.id
}

# Create the control plane security group
resource "aws_security_group" "control_plane_security_group" {
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.eks_vpc.id
}

# Create an IAM role for EKS
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Create the EKS cluster
resource "aws_eks_cluster" "eks" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet_01.id,
      aws_subnet.private_subnet_02.id
    ]
  }

  depends_on = [
    aws_vpc.eks_vpc,
    aws_subnet.private_subnet_01,
    aws_subnet.private_subnet_02,
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# Create an IAM role and policy for the EKS node group
resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
resource "aws_iam_role_policy_attachment" "eks_node_group_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}
resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

# Create the EKS node group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "my-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [aws_subnet.private_subnet_01.id, aws_subnet.private_subnet_02.id]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_policy
  ]
}