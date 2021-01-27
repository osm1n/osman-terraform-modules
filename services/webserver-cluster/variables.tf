# create a variable for port number
variable "server_port" {
  description = "Port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

# cluster name variable

variable "cluster_name" {
  description = "The name for all cluster resource"
  type = string
}

# instance type name
# this will allow for chosing different instance type for prod or stage
variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}


# variable for bucket name
variable "db_remote_state_bucket" {
  description = "S3 bucket name used for DB remote state storage"
  type = string
}

# variable for remote key name
variable "db_remote_state_key" {
  description = "path for the DB's remote state in S3"
  type = string
}

# for ASG max and min dis will allow changing the number instance to run for staging and prod

variable "min_size" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}