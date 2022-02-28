
variable "identity" {
  description = <<-EOT
Unique project identity objecty. Containts:
project - Unique project identifier across entire organization.
environment - Name of environment. Possible values: dev[1-9]+, test[1-9]+, qa[1-9]+, green[1-9]+, blue[1-9]+, stage[1-9]+, uat[1-9]+, prod[1-9]+.
project_repo - Name of project repository which uses this module.
EOT
  type = object({
    project     = string
    environment = string
    project_repo = string
  })
  validation {
    condition     = contains(flatten([for env_name in ["dev", "test", "qa", "green", "blue", "stage", "uat", "prod"] : [for num in ["", "1", "2", "3", "4", "5", "6", "7", "8", "9"] : "${env_name}${num}"]]), var.identity.environment) && length(var.identity.project) >= 2 && length(var.identity.project) <= 10
    error_message = "Invalid value for environment or Project variable length must be between 2 and 10 characters."
  }
}

variable "context" {
  type        = string
  description = "Context of module usage. Will be used as name/id in all created resources. Max 10 characters. E.g. `backend`, `frontend` etc."
  validation {
    condition     = length(var.context) >= 2 && length(var.context) <= 10
    error_message = "The `context` variable length must be between 2 and 10 characters."
  }
}



# aws_rds_cluster
variable "enabled" {
  description = "Indicates whether all resources inside module should be created (affects nearly all resources)"
  type        = bool
  default     = true
}
variable "port" {
  description = "The port on which the DB accepts connections. Defaults to aurora-postgres port `5432`"
  type        = string
  default     = "5432"
}

variable "engine" {
  description = "The name of the database engine to be used for this DB cluster. Defaults to `aurora-postgresql`. Valid Values: `aurora`, `aurora-mysql`, `aurora-postgresql`"
  type        = string
  default     = "aurora-postgresql"
  validation {
    condition     = contains(["aurora", "aurora-mysql", "aurora-postgresql"], var.engine)
    error_message = "Allowed values for engine are \"aurora\", \"aurora-mysql\", or \"aurora-postgresql\"."
  }
}

variable "random_password_length" {
  description = "Length of random password to create. Defaults to `10`"
  type        = number
  default     = 10
}


variable "engine_mode" {
  description = "The database engine mode. Valid values: `global`, `multimaster`, `parallelquery`, `provisioned`. Defaults to: `provisioned`."
  type        = string
  default     = "provisioned"
  validation {
    condition     = contains(["global", "parallelquery", "provisioned", "multimaster"], var.engine_mode)
    error_message = "Allowed values for engine_mode are \"global\", \"parallelquery-mysql\", \"provisioned\", or \"multimaster\"."
  }
}
# Enhanced monitoring
variable "enhanced_monitoring_enabled" {
  description = "Flag indicates whether RDS enhanced monitoring role is enabled. By default enhanced motoring is turned on."
  type        = bool
  default     = true
}
variable "enhanced_monitoring_external_role_arn" {
  description = "ARN of external IAM role for RDS enhanced monitoring. When 'enhanced_monitoring_external_role_arn' is null. IAM role is created internally in module. Defaults to null."
  type        = string
  default     = null
}
variable "enhanced_monitoring_interval_seconds" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected for instances. Default is `60`"
  type        = number
  default     = 60
}

# RDS security group configuration


variable "backtrack_window" {
  description = "The target backtrack window, in seconds. Only available for `aurora` engine currently. To disable backtracking, set this value to 0. Must be between 0 and 259200 (72 hours)"
  type        = number
  default     = null
}

variable "apply_immediately" {
  description = "Specifies whether any cluster modifications are applied immediately, or during the next maintenance window. Default is `false`"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "Specifies whether or not to create this cluster from a snapshot. You can use either the name or ARN when specifying a DB cluster snapshot, or the ARN when specifying a DB snapshot"
  type        = string
  default     = null
}

variable "engine_version" {
  description = "The database engine version. Updating this argument results in an outage"
  type        = string
  default     = null
}

variable "ca_cert_identifier" {
  description = "The identifier of the CA certificate for the DB instance"
  type        = string
  default     = null
}

# aws_rds_cluster_role_association
variable "iam_roles" {
  description = "Map of IAM roles and supported feature names to associate with the cluster"
  type        = map(map(string))
  default     = {}
}

# aws_db_subnet_group
variable "create_db_subnet_group" {
  description = "Determines whether to create the databae subnet group or use existing"
  type        = bool
  default     = true
}

variable "db_subnet_group_name" {
  description = "The name of the subnet group name (existing or created)"
  type        = string
  default     = ""
}

variable "subnets" {
  description = "List of subnet IDs used by database subnet group created"
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "instance_class" {
  description = "Instance type to use at master instance. Note: if `autoscaling_enabled` is `true`, this will be the same instance class used on instances created by autoscaling"
  type        = string
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key."
  type        = string
}

variable "default_database_name" {
  description = "Name for an automatically created database on cluster creation. Defaults to `default`"
  type        = string
  default     = "default_db"
}

variable "master_username" {
  description = "Username for the master DB user. Defaults to `root`"
  type        = string
  default     = "root"
}

variable "preferred_backup_window" {
  description = "The daily time range during which automated backups are created if automated backups are enabled using the `backup_retention_period` parameter. Time in UTC"
  type        = string
  default     = "02:00-03:00"
}

variable "preferred_maintenance_window" {
  description = "The weekly time range during which system maintenance can occur, in (UTC)"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "vpc_id" {
  description = "ID of the VPC where to security group is created."
  type        = string
}

variable "iam_database_authentication_enabled" {
  description = "Specifies whether or mappings of AWS Identity and Access Management (IAM) accounts to database accounts is enabled."
  type        = bool
  default     = null
}
variable "auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window. Default `true`"
  type        = bool
  default     = true
}

variable "instances_count" {
  description = "Indicates the number of db instances. Default `2`"
  type        = number
  default     = 2
}

variable "performance_insights_enabled" {
  description = "Specifies whether Performance Insights is enabled or not"
  type        = bool
  default     = null
}

variable "performance_insights_kms_key_id" {
  description = "The ARN for the KMS key to encrypt Performance Insights data"
  type        = string
  default     = null
}

variable "performance_insights_retention_period" {
  description = "Amount of time in days to retain Performance Insights data. Either 7 (7 days) or 731 (2 years)"
  type        = number
  default     = null
}

variable "db_parameter_group_name" {
  description = "The name of the DB parameter group to associate with instances"
  type        = string
  default     = null
}

variable "db_cluster_parameter_group_name" {
  description = "A cluster parameter group to associate with the cluster"
  type        = string
  default     = null
}

variable "db_cluster_db_instance_parameter_group_name" {
  description = "Instance parameter group to associate with all instances of the DB cluster. The `db_cluster_db_instance_parameter_group_name` is only valid in combination with `allow_major_version_upgrade`"
  type        = string
  default     = null
}

variable "allow_major_version_upgrade" {
  description = "Enable to allow major engine version upgrades when changing engine versions. Defaults to `false`"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Determines whether a final snapshot is created before the cluster is deleted. If true is specified, no snapshot is created"
  type        = bool
  default     = null
}

variable "deletion_protection" {
  description = "If the DB instance should have deletion protection enabled. The database can't be deleted when this value is set to `true`. The default is `false`"
  type        = bool
  default     = null
}

variable "backup_retention_period" {
  description = "The days to retain backups for. Default `7`"
  type        = number
  default     = 7
}
variable "copy_tags_to_snapshot" {
  description = "Copy all Cluster `tags` to snapshots"
  type        = bool
  default     = true
}
