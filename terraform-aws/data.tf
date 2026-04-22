data "aws_partition" "current" {}

data "aws_vpc" "default" {
  count   = local.explicit_vpc_id == "" && var.use_default_vpc ? 1 : 0
  default = true
}

data "aws_subnets" "lambda" {
  count = local.use_vpc ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.selected_vpc_id]
  }
}
