variable "project" {
  type        = string
  description = "Project acronym. Min 2 characters, max 4 characters."
  validation {
    condition     = length(var.project) >= 2 && length(var.project) <= 4
    error_message = "Project variable length must be between 2 and 4 characters."
  }
}

variable "context" {
  type        = string
  description = "Optional context of module usage. Max 10 characters. E.g. `backend`, `frontend` etc."
  validation {
    condition     = length(var.context) >= 2 && length(var.context) <= 10
    error_message = "The `context` variable length must be between 2 and 10 characters."
  }
}

variable "environment" {
  type        = string
  description = "Environment acronym. Valid Values: `prod`, `green`, `blue`, `stage`, `uat`, `qa`, `test`, `dev`"
  validation {
    condition     = contains(["prod", "green", "blue", "stage", "uat", "qa", "test", "dev"], var.environment)
    error_message = "Allowed values for engine are \"prod\", \"green\", \"blue\", \"stage\", \"uat\", \"qa\", \"test\", or \"dev\"."
  }
}

variable "workload" {
  type        = string
  description = "Workload acronym. Valid Values: `prod`, `non-prod`"
  validation {
    condition     = contains(["prod", "non-prod"], var.workload)
    error_message = "Allowed values for workload are \"prod\", \"non-prod\"."
  }
}

# aws_rds_cluster
variable "create_cluster" {
  description = "Whether cluster should be created (affects nearly all resources)"
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
  description = "The database engine mode. Valid values: `global`, `multimaster`, `parallelquery`, `provisioned`. Defaults to: `provisioned`"
  type        = string
  default     = "provisioned"
  validation {
    condition     = contains(["global", "parallelquery", "provisioned", "multimaster"], var.engine_mode)
    error_message = "Allowed values for engine_mode are \"global\", \"parallelquery-mysql\", \"provisioned\", or \"multimaster\"."
  }
}

# Enhanced monitoring role
variable "create_monitoring_role" {
  description = "Determines whether to create the IAM role for RDS enhanced monitoring"
  type        = bool
  default     = true
}

variable "monitoring_role_arn" {
  description = "IAM role used by RDS to send enhanced monitoring metrics to CloudWatch"
  type        = string
  default     = ""
}

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
  default     = []
}

variable "extra-tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "instance_class" {
  description = "Instance type to use at master instance. Note: if `autoscaling_enabled` is `true`, this will be the same instance class used on instances created by autoscaling"
  type        = string
}
# aws_appautoscaling_*
variable "autoscaling_enabled" {
  description = "Determines whether autoscaling of the cluster read replicas is enabled"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key."
  type        = string
}

variable "database_name" {
  description = "Name for an automatically created database on cluster creation. Defaults to `default`"
  type        = string
  default     = "default"
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

variable "monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected for instances. Set to `0` to disble. Default is `0`"
  type        = number
  default     = 0
}

variable "vpc_id" {
  description = "ID of the VPC where to security group is created"
  type        = string
}

variable "iam_database_authentication_enabled" {
  description = "Specifies whether or mappings of AWS Identity and Access Management (IAM) accounts to database accounts is enabled"
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
