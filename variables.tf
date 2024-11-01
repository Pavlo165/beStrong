# Define variables
variable "location" {
  default = "polandcentral"
}
variable "resource_group_name" {
  default = "beStrongApp"
}
variable "TF_VAR_password_for_sql" {
  description = "Password"
  type        = string
}