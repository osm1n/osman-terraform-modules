#provider is configured by the user of the module not the module so provider is removed here

# jus made some bullshit changes

# jus got github shit
# create instance
# different from the ones used in single EC2
resource "aws_launch_configuration" "terraform-2-instance" {
  image_id        = "ami-0c55b159cbfafe1f0"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.terraform-sec.id] # for opening port 80

  # script added as a separate file now we jus use the data source
  user_data = data.template_file.user_data.rendered


  # Required when using a launch configuration with an auto scaling group.
  # ensures a resource is created before deleting the old one 
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html

  lifecycle {
    create_before_destroy = true
  }

}

# use data source to pull info from db data source
# instead typing it out here we can include a file

# file("user-data.sh")
# above wont work cuz we are pulling some dynamic data from the instance
# so we use below

data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    server_port = var.server_port
    db_address = data.terraform_remote_state.db.outputs.address
    db_port = data.terraform_remote_state.db.outputs.port
  }
}

# i dont get dis part really
# but i know its get the default VPC zone
# a data source provides read only that we request from the provider
# it does not create anything jus make API request for shit like IP, subnet, etc

# look for default VPC zone
data "aws_vpc" "default" {
  default = true
}

# usin the data source queired above
# we can now query the subnets the VPC belongs to
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# define all the local variables used below aka Module Locals

locals {
  http_port = 80
  any_port = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips = ["0.0.0.0/0"]
}


#create ASG resource
resource "aws_autoscaling_group" "terraform-asg" {
  launch_configuration = aws_launch_configuration.terraform-2-instance.name

  # to pull subnet ids out of the aws_subnet_ids data source created above
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  # add target groups for LB
  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB" #default is EC2, ELB is more robust cuz it uses the ASG target group defined below

  # max and min nodes/servers
  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}


# add security group to open port 8080 for the web app
# everything using variables
# this style makes it easier to open more ports by jus creating new rules
resource "aws_security_group" "terraform-sec" {
  name = "${var.cluster_name}-terraform-sec"

}

# we can easily add another port as below in stage or prod
# no more inline blocks - now using security rules
resource "aws_security_group_rule" "allow_server_http_inbound" {
  type = "ingress"
  security_group_id = aws_security_group_terraform-sec.id

  from_port   = var.server_port
  to_port     = var.server_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips

}

#Create a load balancer
resource "aws_lb" "terraform-lb" {
  name               = var.cluster_name
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids # using data source created above

  # adding defined security group that opens port 80 above
  security_groups = [aws_security_group.alb.id]
}

# create a listener for lb
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.terraform-lb.arn
  port              = local.http_port
  protocol          = "HTTP"

  # by default return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: sorry buddy, page not found"
      status_code  = 404
    }
  }

}

# create a target group for the lb 
# this will tell the lb which server to send which traffic to 
# absolute path can be used here such as foo/bar
# or domain can be used foo.example.com

resource "aws_lb_target_group" "asg" {
  name     = var.cluster_name
  port     = var.server_port # dis 8080 variable declared above
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  # perform health checks periodically by sending http request to each instance
  # response needs to match the matcher (look for 200 oK)
  # if it returns anything else the instance is failed or overloaded and will be marked as unhealthy
  # traffic will be redirected to other instances

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


# create a listerner rule to tie shit together
# adds a listener ruler that sends requests that match any path on the target group in the ASG
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }

  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}


# create a security group for port 80 for the lb listener to use
resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"

}

# crete security rule without using the old inline blocks
resource "aws_security_group_rule" "allow_http_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips

}

# create egress security rule 
resource "aws_security_group_rule" "allow_all_outbound" {
  type = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}

# Partial configuration. The other settings (e.g., bucket, region) will be #
# passed in from a file via -backend-config arguments to 'terraform init' terraform
# instead of using above code now split into two files

#terraform {
 # backend "s3" {
  #  key = "stage/services/webserver-cluster/terraform.tfstate"
   # bucket = "usman-bucket"
    #region = "us-east-2"

  #}
#}

# Read Database connection state file from the S3 bucket of mysql/terraform.tfstate
# this configures the web server cluster to read the state file from the S3 bucket
# and folder to locate the database state file

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    #key = "stage/data-stores/mysql/terraform.tfstate"
    key = var.db_remote_state_key
    region = "us-east-2"
  }
}

