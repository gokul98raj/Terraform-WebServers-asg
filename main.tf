provider "aws" {
  profile = "default"
}

resource "aws_launch_template" "web-launch-template" {
  name          = "web-launch-template"
  description   = "Launch Configuration for Web Server"
  image_id      = "ami-0d13e3e640877b0b9"
  instance_type = "t2.micro"
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = "8"
    }
  }
  vpc_security_group_ids = [aws_security_group.web-security-group.id]
  key_name               = "ap-south-1"
  user_data              = filebase64("ec2-user-data.sh")
}

resource "aws_security_group" "web-security-group" {
  name   = "web-security-group"
  vpc_id = aws_default_vpc.main-vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all the ports"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_default_vpc" "main-vpc" {

}

resource "aws_autoscaling_group" "web-asg" {
  name                      = "web-asg"
  desired_capacity          = 2
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = "60"
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["subnet-698dbc01", "subnet-fdb1d7b1"]
  launch_template {
    id      = aws_launch_template.web-launch-template.id
    version = "$Latest"
  }

}

//Target tracking scaling policy
resource "aws_autoscaling_policy" "web-asg-policy" {
  name                   = "web-asg-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web-asg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = "60"
  }

}

resource "aws_autoscaling_attachment" "web-asg-attachment" {
  autoscaling_group_name = aws_autoscaling_group.web-asg.id
  lb_target_group_arn    = aws_lb_target_group.web-target-group.arn

}

resource "aws_lb" "web-lb" {
  name               = "web-lb"
  internal           = "false"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-security-group.id]
  subnets            = ["subnet-698dbc01", "subnet-fdb1d7b1"]

}

resource "aws_lb_target_group" "web-target-group" {
  name     = "web-target-group"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.main-vpc.id

}

resource "aws_lb_listener" "web-lb-listener" {
  load_balancer_arn = aws_lb.web-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-target-group.arn
  }
}