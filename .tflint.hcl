rule "aws_resource_missing_tags" {
  enabled = true
  tags = [
    "Environment",
    "Project",
    "TerraformModule",
    "ProjectRepository"
  ]
}
