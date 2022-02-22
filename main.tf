locals {
  port = coalesce(var.port, (var.engine == "aurora-postgresql" ? 5432 : 3306))

  db_subnet_group_name          = var.create_db_subnet_group ? join("", aws_db_subnet_group.this.*.name) : var.db_subnet_group_name
  internal_db_subnet_group_name = try(coalesce(var.db_subnet_group_name, local.name), "")
  master_password               = random_password.master_password[0].result
  backtrack_window              = var.engine == "aurora-mysql" || var.engine == "aurora" ? var.backtrack_window : 0

  rds_enhanced_monitoring_arn = var.create_monitoring_role ? join("", aws_iam_role.rds_enhanced_monitoring.*.arn) : var.monitoring_role_arn
  rds_security_group_id       = join("", aws_security_group.this.*.id)
  #fixed params - not allowed to be changed
  storage_encrypted           = true
  skip_final_snapshot         = false
  deletion_protection         = true
  copy_tags_to_snapshot       = true
  allow_major_version_upgrade = false
  publicly_accessible         = false
  backup_retention_period     = var.workload == "prod" ? 35 : 7
  default-tags = {
    Project         = var.project
    Environment     = var.environment
    AppName         = var.context
    TerraformModule = "rds-aurora"
  }
  tags = merge(local.default-tags, var.extra-tags)
  #resources names
  name                          = "${var.project}-${var.context}-${var.environment}"
  sg_gr_name                    = "${var.project}-${var.context}-rds-traffice-${var.environment}"
  enhanced_monitoring_role_name = "${var.project}-${var.context}-rds-enhanced-monitring-${var.environment}"
}

# Ref. https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html#genref-aws-service-namespaces
data "aws_partition" "current" {}

# Random string to use as master password
resource "random_password" "master_password" {
  count = var.create_cluster ? 1 : 0

  length  = var.random_password_length
  special = false
}

resource "random_id" "snapshot_identifier" {
  count = var.create_cluster ? 1 : 0
  keepers = {
    id = local.name
  }

  byte_length = 4
}

resource "aws_db_subnet_group" "this" {
  count = var.create_cluster && var.create_db_subnet_group ? 1 : 0

  name        = local.internal_db_subnet_group_name
  description = "For Aurora cluster ${local.name}"
  subnet_ids  = var.subnets

  tags = local.tags
}

resource "aws_rds_cluster" "this" {
  count = var.create_cluster ? 1 : 0

  cluster_identifier = local.name

  engine                              = var.engine
  engine_mode                         = var.engine_mode
  engine_version                      = var.engine_version
  allow_major_version_upgrade         = local.allow_major_version_upgrade
  kms_key_id                          = var.kms_key_id
  database_name                       = var.database_name
  master_username                     = var.master_username
  master_password                     = local.master_password
  final_snapshot_identifier           = "${local.name}-${element(concat(random_id.snapshot_identifier.*.hex, [""]), 0)}"
  skip_final_snapshot                 = local.skip_final_snapshot
  deletion_protection                 = local.deletion_protection
  backup_retention_period             = local.backup_retention_period
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
  copy_tags_to_snapshot               = local.copy_tags_to_snapshot

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
  for_each = var.create_cluster ? var.instances_count : 0

  # Notes:
  # Do not set preferred_backup_window - its set at the cluster level and will error if provided here

  identifier                            = "${local.name}-${each.key}"
  cluster_identifier                    = try(aws_rds_cluster.this[0].id, "")
  engine                                = var.engine
  engine_version                        = var.engine_version
  instance_class                        = var.instance_class
  publicly_accessible                   = local.publicly_accessible
  db_subnet_group_name                  = local.db_subnet_group_name
  db_parameter_group_name               = var.db_parameter_group_name
  apply_immediately                     = var.apply_immediately
  monitoring_role_arn                   = local.rds_enhanced_monitoring_arn
  monitoring_interval                   = var.monitoring_interval
  preferred_maintenance_window          = var.preferred_maintenance_window
  auto_minor_version_upgrade            = var.auto_minor_version_upgrade
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_kms_key_id
  performance_insights_retention_period = var.performance_insights_retention_period
  copy_tags_to_snapshot                 = local.copy_tags_to_snapshot
  ca_cert_identifier                    = var.ca_cert_identifier

  tags = local.tags
}


resource "aws_rds_cluster_role_association" "this" {
  for_each = var.create_cluster ? var.iam_roles : {}

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
  count = var.create_cluster && var.create_monitoring_role && var.monitoring_interval > 0 ? 1 : 0

  name        = local.enhanced_monitoring_role_name
  description = "Enhanced monitoing Role for RDS Aurora ${local.name}"

  tags               = local.tags
  assume_role_policy = data.aws_iam_policy_document.monitoring_rds_assume_role.json
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.create_cluster && var.create_monitoring_role && var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "this" {
  count = var.create_cluster ? 1 : 0

  name        = local.sg_gr_name
  vpc_id      = var.vpc_id
  description = "Control traffic to/from RDS Aurora ${local.name}"

  tags = merge(local.tags, { Name = local.sg_gr_name })
}
#
## TODO - change to map of ingress rules under one resource at next breaking change
#resource "aws_security_group_rule" "default_ingress" {
#  count = var.create_cluster ? length(var.allowed_security_groups) : 0
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
#  count = var.create_cluster && length(var.allowed_cidr_blocks) > 0 ? 1 : 0
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
#  for_each = var.create_cluster ? var.security_group_egress_rules : {}
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
