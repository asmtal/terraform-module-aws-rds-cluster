locals {
  module_name          = "terraform-module-aws-rds-cluster"
  computed_module_name = var.parent_terraform_module != null ? "${var.parent_terraform_module}/${local.module_name}" : local.module_name
  port                 = coalesce(var.port, (var.engine == "aurora-postgresql" ? 5432 : 3306))

  db_subnet_group_name          = var.create_db_subnet_group ? join("", aws_db_subnet_group.this.*.name) : var.db_subnet_group_name
  internal_db_subnet_group_name = try(coalesce(var.db_subnet_group_name, local.name), "")
  backtrack_window              = var.engine == "aurora-mysql" || var.engine == "aurora" ? var.backtrack_window : 0

  rds_security_group_id = join("", aws_security_group.this.*.id)

  tags = merge({
    TerraformModule = local.computed_module_name
  }, var.tags)
  #resources names
  name        = "${var.identity.project}-${var.context}-${var.identity.environment}"
  secret_name = "${var.identity.project}-${var.context}-rds-credentials-${var.identity.environment}"
  sg_gr_name  = "${var.identity.project}-${var.context}-rds-traffic-${var.identity.environment}"

  # enhanced monitoring start
  enhanced_monitoring_role_name   = "${var.identity.project}-${var.context}-rds-enhanced-monitring-${var.identity.environment}"
  create_enhanced_monitoring_role = var.enhanced_monitoring_enabled && var.enhanced_monitoring_external_role_arn == null
  enhanced_monitoring_role_arn    = local.create_enhanced_monitoring_role ? join("", aws_iam_role.rds_enhanced_monitoring.*.arn) : var.enhanced_monitoring_external_role_arn
  # enhanced monitoring end

  db_credentials_json = {
    username = var.master_username
    password = join("", random_password.master_password[*].result)
    name     = var.default_database_name
    port     = local.port
  }

  # use default aws key for rds if kms_key_arn is not passed
  kms_key_arn = var.kms_key_arn == null ? data.aws_kms_key.aws_rds.arn : var.kms_key_arn

  # fixed params start - not allowed to be changed
  storage_encrypted   = true
  publicly_accessible = false
  # fixed params end - not allowed to be changed
}
# default rds kms key
data "aws_kms_key" "aws_rds" {
  key_id = "alias/aws/rds"
}
# Ref. https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html#genref-aws-service-namespaces
data "aws_partition" "current" {}

# Random string to use as master password
resource "random_password" "master_password" {
  count = var.enabled ? 1 : 0

  length  = var.random_password_length
  special = false
}

resource "random_id" "snapshot_identifier" {
  count = var.enabled ? 1 : 0
  keepers = {
    id = local.name
  }

  byte_length = 4
}

resource "aws_db_subnet_group" "this" {
  count = var.enabled && var.create_db_subnet_group ? 1 : 0

  name        = local.internal_db_subnet_group_name
  description = "For Aurora cluster ${local.name}"
  subnet_ids  = var.subnets

  tags = local.tags
}

resource "aws_rds_cluster" "this" {
  count = var.enabled ? 1 : 0

  cluster_identifier = local.name

  engine                              = var.engine
  engine_mode                         = var.engine_mode
  engine_version                      = var.engine_version
  allow_major_version_upgrade         = var.allow_major_version_upgrade
  kms_key_id                          = local.kms_key_arn
  database_name                       = var.default_database_name
  master_username                     = local.db_credentials_json.username
  master_password                     = local.db_credentials_json.password
  final_snapshot_identifier           = "${local.name}-${element(concat(random_id.snapshot_identifier.*.hex, [""]), 0)}"
  skip_final_snapshot                 = var.skip_final_snapshot
  deletion_protection                 = var.deletion_protection
  backup_retention_period             = var.backup_retention_period
  preferred_backup_window             = var.preferred_backup_window
  preferred_maintenance_window        = var.preferred_maintenance_window
  port                                = local.port
  db_subnet_group_name                = local.db_subnet_group_name
  vpc_security_group_ids              = compact(aws_security_group.this.*.id)
  snapshot_identifier                 = var.snapshot_identifier
  storage_encrypted                   = local.storage_encrypted
  apply_immediately                   = var.apply_immediately
  db_cluster_parameter_group_name     = var.db_cluster_parameter_group_name
  db_instance_parameter_group_name    = var.db_cluster_db_instance_parameter_group_name
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  backtrack_window                    = local.backtrack_window
  copy_tags_to_snapshot               = var.copy_tags_to_snapshot

  lifecycle {
    ignore_changes = [
      # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster#replication_source_identifier
      # Since this is used either in read-replica clusters or global clusters, this should be acceptable to specify
      replication_source_identifier,
      # See docs here https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_global_cluster#new-global-cluster-from-existing-db-cluster
      global_cluster_identifier,
    ]
  }

  tags = local.tags
}

resource "aws_rds_cluster_instance" "this" {
  count = var.enabled ? var.instances_count : 0

  # Notes:
  # Do not set preferred_backup_window - its set at the cluster level and will error if provided here

  identifier                            = "${local.name}-${count.index}"
  cluster_identifier                    = try(aws_rds_cluster.this[0].id, "")
  engine                                = var.engine
  engine_version                        = var.engine_version
  instance_class                        = var.instance_class
  publicly_accessible                   = local.publicly_accessible
  db_subnet_group_name                  = local.db_subnet_group_name
  db_parameter_group_name               = var.db_parameter_group_name
  apply_immediately                     = var.apply_immediately
  monitoring_role_arn                   = local.enhanced_monitoring_role_arn
  monitoring_interval                   = var.enhanced_monitoring_interval_seconds
  preferred_maintenance_window          = var.preferred_maintenance_window
  auto_minor_version_upgrade            = var.auto_minor_version_upgrade
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_kms_key_id
  performance_insights_retention_period = var.performance_insights_retention_period
  copy_tags_to_snapshot                 = var.copy_tags_to_snapshot
  ca_cert_identifier                    = var.ca_cert_identifier

  tags = local.tags
}


resource "aws_rds_cluster_role_association" "this" {
  for_each = var.enabled ? var.iam_roles : {}

  db_cluster_identifier = try(aws_rds_cluster.this[0].id, "")
  feature_name          = each.value.feature_name
  role_arn              = each.value.role_arn
}

################################################################################
# Enhanced Monitoring
################################################################################

data "aws_iam_policy_document" "monitoring_rds_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.enabled && local.create_enhanced_monitoring_role ? 1 : 0

  name               = local.enhanced_monitoring_role_name
  description        = "Enhanced monitoing Role for RDS Aurora ${local.name}"
  assume_role_policy = data.aws_iam_policy_document.monitoring_rds_assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.enabled && local.create_enhanced_monitoring_role ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "this" {
  count = var.enabled ? 1 : 0

  name        = local.sg_gr_name
  vpc_id      = var.vpc_id
  description = "Controls traffic to/from RDS Aurora ${local.name}"

  tags = merge({ Name = local.sg_gr_name }, local.tags)
}
#
## TODO - change to map of ingress rules under one resource at next breaking change
#resource "aws_security_group_rule" "default_ingress" {
#  count = var.enabled ? length(var.allowed_security_groups) : 0
#
#  description = "From allowed SGs"
#
#  type                     = "ingress"
#  from_port                = local.port
#  to_port                  = local.port
#  protocol                 = "tcp"
#  source_security_group_id = element(var.allowed_security_groups, count.index)
#  security_group_id        = local.rds_security_group_id
#}
#
## TODO - change to map of ingress rules under one resource at next breaking change
#resource "aws_security_group_rule" "cidr_ingress" {
#  count = var.enabled && length(var.allowed_cidr_blocks) > 0 ? 1 : 0
#
#  description = "From allowed CIDRs"
#
#  type              = "ingress"
#  from_port         = local.port
#  to_port           = local.port
#  protocol          = "tcp"
#  cidr_blocks       = var.allowed_cidr_blocks
#  security_group_id = local.rds_security_group_id
#}
#
#resource "aws_security_group_rule" "egress" {
#  for_each = var.enabled ? var.security_group_egress_rules : {}
#
#  # required
#  type              = "egress"
#  from_port         = lookup(each.value, "from_port", local.port)
#  to_port           = lookup(each.value, "to_port", local.port)
#  protocol          = "tcp"
#  security_group_id = local.rds_security_group_id
#
#  # optional
#  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
#  description              = lookup(each.value, "description", null)
#  ipv6_cidr_blocks         = lookup(each.value, "ipv6_cidr_blocks", null)
#  prefix_list_ids          = lookup(each.value, "prefix_list_ids", null)
#  source_security_group_id = lookup(each.value, "source_security_group_id", null)
#}

module "database_credentials_secrets_manager" {
  source                  = "git@github.com:ck-ev-test/terraform-module-aws-secrets-manager.git?ref=v1.1.2"
  enabled                 = var.enabled
  identity                = var.identity
  context                 = "${var.context}-rds-credentials"
  description             = "Database credentails for RDS Aurora ${local.name}"
  secret_string           = jsonencode(local.db_credentials_json)
  parent_terraform_module = local.computed_module_name
  tags                    = local.tags
}
