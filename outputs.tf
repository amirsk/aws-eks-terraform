output "vpc_id" {
  value = aws_vpc.eks_vpc.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.internet_gateway.id
}

output "public_route_table_id" {
  value = aws_route_table.public_route_table.id
}

output "private_route_table_01_id" {
  value = aws_route_table.private_route_table_01.id
}

output "private_route_table_02_id" {
  value = aws_route_table.private_route_table_02.id
}

output "nat_gateway_01_id" {
  value = aws_nat_gateway.nat_gateway_01.id
}

output "nat_gateway_02_id" {
  value = aws_nat_gateway.nat_gateway_02.id
}

output "nat_gateway_eip_01_id" {
  value = aws_eip.nat_gateway_eip_01.id
}

output "nat_gateway_eip_02_id" {
  value = aws_eip.nat_gateway_eip_01.id
}

output "public_subnet_01_id" {
  value = aws_subnet.public_subnet_01.id
}

output "public_subnet_02_id" {
  value = aws_subnet.public_subnet_02.id
}

output "private_subnet_01_id" {
  value = aws_subnet.private_subnet_01.id
}

output "private_subnet_02_id" {
  value = aws_subnet.private_subnet_02.id
}

output "control_plane_security_group_id" {
  value = aws_security_group.control_plane_security_group.arn
}

output "eks_cluster_id" {
  value = aws_eks_cluster.eks.id
}

output "node_group_id" {
  value = aws_eks_node_group.eks_node_group.id
}

output "provider_name" {
  value = local.provider_name
}

output "helm_name" {
  value = helm_release.aws_load_balancer_controller.name
}