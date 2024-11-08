# Define variables
variable "location" {
  description = "Location for majority resourse"
  default     = "westeurope"
}
variable "resource_group_name" {
  description = "Name for resourse group"
  default     = "beStrongApp"
}
variable "password_for_sql" {
  description = "Password for sql server"
  sensitive = true
}
variable "login_for_sql" {
  description = "Login for sql server"
  sensitive   = true
}