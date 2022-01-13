provider "aws" {
    access_key = var.access_key
    secret_key = var.secret_key
    region     = "eu-central-1"
}

data "aws_availability_zones" "avialable" {}

data "aws_ami" "latest_ubuntu_linux" {
    owners      = ["099720109477"]
    most_recent = true
    filter {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
}

resource "aws_security_group" "web_security_group" {
    name         = "Dynamic web security group"

    dynamic "ingress" {
        for_each = ["80", "443", "22"]
        content {
            from_port   = ingress.value
            to_port     = ingress.value
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
        }
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name  = "Security group for Web_Serves"
        Owner = "Anton Chelyshkov"
    }
}

resource "aws_launch_configuration" "web" {
    name            = "WebServer-Highly-Available-LC"
    image_id        = data.aws_ami.latest_ubuntu_linux.id
    instance_type   = "t2.micro"
    security_groups = [aws_security_group.web_security_group.id]
    user_data       = file("/scripts/user_data.sh")

    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_autoscaling_group" "web_server" {
    name = "WebServer-Highly-Available-ASG"
    launch_configuration = aws_launch_configuration.web.name
    min_size             = 2
    max_size             = 2
    min_elb_capacity     = 2
    health_check_type    = "ELB"
    vpc_zone_identifier  = [aws_default_subnet.default_sub_1.id, aws_default_subnet.default_sub_2.id] 
    load_balancers       = [aws_elb.balancer.name]
    dynamic "tag"{
        for_each = {
            Name  = "WebServers-in-ASG"
            Owner = "Anton Chelyshkov"
        }
        content {
            key                 = tag.key
            value               = tag.value
            propagate_at_launch = true
        }
    }

    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_elb" "balancer" {
    name = "WebServer-HA-ELB"
    availability_zones = [data.aws_availability_zones.avialable.names[0], data.aws_availability_zones.avialable.names[1]]
    security_groups    = [aws_security_group.web_security_group.id]
    
    listener {
      lb_port           = 80
      lb_protocol       = "http"
      instance_port     = 80
      instance_protocol = "http"
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        target              = "HTTP:80/"
        interval            = 10
    }

    tags = {
      Name = "WebServer-Highly-Available-ELB"
    }
}

resource "aws_default_subnet" "default_sub_1" {
    availability_zone = data.aws_availability_zones.avialable.names[0]
}

resource "aws_default_subnet" "default_sub_2" {
    availability_zone = data.aws_availability_zones.avialable.names[1]
}