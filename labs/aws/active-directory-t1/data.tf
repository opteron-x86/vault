data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

module "ami" {
  source = "../modules/ami-lookup"
}