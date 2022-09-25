############################
# PROVIDERR
############################

terraform {
  backend "s3" {
    bucket = "terraform-up-and-running-state-nax"    # This backend automatically push and pull terraform.tfstate file into s3 bucket
    key    = "global/s3/terraform.tfstate"
    region = "us-east-1"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

############################
#  VPC MODULE
############################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks-cluster-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_dns_hostnames = true # Should be true to enable DNS hostnames in the VPC
  enable_dns_support   = true # Should be true to enable DNS support in the VPC
  enable_nat_gateway   = false

  tags = {
    Terraform   = "true"
    Environment = "devops"
  }
}

############################
# EKS ROLE
############################

resource "aws_iam_role" "eks-iam-role" {
  name = "devopsthehardway-eks-iam-role"

  path = "/"

  assume_role_policy = <<EOF
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
EOF

}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-iam-role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-iam-role.name
}

############################
# EKS CLUSTER
############################

resource "aws_eks_cluster" "devopsthehardway-eks" {
  name     = "devopsthehardway-cluster"
  role_arn = aws_iam_role.eks-iam-role.arn

  vpc_config {
    subnet_ids = [element(module.vpc.public_subnets, 0), element(module.vpc.public_subnets, 1)]
  }

  depends_on = [
    aws_iam_role.eks-iam-role,
    module.vpc
  ]
}

############################
# WORKER NODES ROLE
############################

resource "aws_iam_role" "workernodes" {
  name = "eks-node-group-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role       = aws_iam_role.workernodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workernodes.name
}

############################
# WORKER NODES
############################

resource "aws_eks_node_group" "worker-node-group" {
  cluster_name    = aws_eks_cluster.devopsthehardway-eks.name
  node_group_name = "devopsthehardway-workernodes"
  node_role_arn   = aws_iam_role.workernodes.arn
  subnet_ids      = [element(module.vpc.public_subnets, 0), element(module.vpc.public_subnets, 0)]
  instance_types  = ["t3a.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    #aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}