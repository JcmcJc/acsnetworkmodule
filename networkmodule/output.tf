# Add output variables
output "subnet_id" {
  value = aws_subnet.public[*].id
}
#Private subnet
output "private_subnet_id" {
  value = aws_subnet.private[*].id
}

output "vpc_id" {
  value = aws_vpc.main.id
}
#output "dev_route_table" {
 # value = aws_route_table.public_subnets.id
#}