terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.1"
    }
  }

  required_version = ">= 1.2.0"

}

provider "aws" {
  region = "eu-west-2"
}

data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.eks.name
}
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.cluster.endpoint
    token = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
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
  depends_on = [
    aws_internet_gateway.internet_gateway
  ]
}
resource "aws_eip" "nat_gateway_eip_02" {
  domain = "vpc"
  depends_on = [
    aws_internet_gateway.internet_gateway
  ]
}

# Create the public subnets
resource "aws_subnet" "public_subnet_01" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public_subnet_01_block
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2a"
  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "public_subnet_02" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public_subnet_02_block
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2b"
  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

# Create the private subnets
resource "aws_subnet" "private_subnet_01" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.private_subnet_01_block
  map_public_ip_on_launch = false
  availability_zone       = "eu-west-2a"
  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_subnet" "private_subnet_02" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.private_subnet_02_block
  map_public_ip_on_launch = false
  availability_zone       = "eu-west-2b"
  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
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
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_policy
  ]
}

# Retrieve TLS certificate for the OIDC identity provider associated with the EKS cluster
data "tls_certificate" "cluster_oidc" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# Create IAM OIDC provider
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster_oidc.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.cluster_oidc.url
}

# VPC CNI plugin
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "vpc-cni"
}

# kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "kube-proxy"
}

# CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "coredns"
  addon_version = "v1.10.1-eksbuild.6"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# Load the policy JSON from a file
data "local_file" "load_balancer_iam_policy_file" {
  filename = "load_balancer_iam_policy.json"
}

# Create the IAM policy
resource "aws_iam_policy" "load_balancer_iam_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = data.local_file.load_balancer_iam_policy_file.content
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {}

locals {
  provider_name = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
}

# Create IAM role
resource "aws_iam_role" "load_balancer_controller_role" {
  name = "AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.provider_name}"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "${local.provider_name}:aud": "sts.amazonaws.com",
        "${local.provider_name}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
      }
    }
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "load_balancer_policy_role_association" {
  policy_arn = aws_iam_policy.load_balancer_iam_policy.arn
  role       = aws_iam_role.load_balancer_controller_role.name
}

# make sure below is ran first! TODO fix
# aws eks update-kubeconfig --region region-code --name my-cluster
# kubectl get svc

resource "helm_release" "aws_load_balancer_controller" {
  chart = "aws-load-balancer-controller"
  name  = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"

  namespace = "kube-system"

  set {
    name = "clusterName"
    value = aws_eks_cluster.eks.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.load_balancer_controller_role.arn
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}