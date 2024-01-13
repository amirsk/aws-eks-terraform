variable "vpc_block" {
  description = "The CIDR range for the VPC. This should be a valid private (RFC 1918) CIDR range."
  default     = "192.168.0.0/16"
}

variable "public_subnet_01_block" {
  description = "CidrBlock for public subnet 01 within the VPC"
  default     = "192.168.0.0/18"
}

variable "public_subnet_02_block" {
  description = "CidrBlock for public subnet 02 within the VPC"
  default     = "192.168.64.0/18"
}

variable "private_subnet_01_block" {
  description = "CidrBlock for private subnet 01 within the VPC"
  default     = "192.168.128.0/18"
}

variable "private_subnet_02_block" {
  description = "CidrBlock for private subnet 02 within the VPC"
  default     = "192.168.192.0/18"
}