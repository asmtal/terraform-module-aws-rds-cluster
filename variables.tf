variable "project" {
  type        = string
  description = "Project acronym. Min 2 characters, max 4 characters."
  validation {
    condition     = length(var.project) >=2 && length(var.project)<=4
    error_message = "Project variable lenght must be between 2 and 4 characters."
  }
}
