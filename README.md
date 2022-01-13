# INSTALL AND TERRAFORM LAUNCH
### Install terraform
To install terraform, I use **Ubuntu 20.04**, so the commands that will be described below are suitable for this version.
To install terraform, I use **Ubuntu 20.04**, so the commands that will be described below are suitable for this version. To install on other versions of **linux** or **windows**, you can refer to the official website [***TERRAFORM***](https://learn.hashicorp.com/tutorials/terraform/install-cli).
```shell
sudo apt update && sudo apt install terraform
```
### Launch terraform
Before launching the application, you need to go to the ["Amazon web services"](https://console.aws.amazon.com/iamv2/home?region=eu-central-1#/users) website and create a user with administrator rights there. There will be given access key and secret key we will use them further. 
In order for the script to work, you need to create a file variables.tf , it should look like this: 
```terraform
variable "access_key" {
  default = "key"
}

variable "secret_key"{
  default = "key"
}
```

In the variable functions where **"defaults"** is written, you will need to insert your keys in place of the key.

Next, you need to write `terraform init` in the console, and then `terraform apply`. Next, Terraform itself will create the necessary files to run on the Amazon cloud service.

# EXPLANATION OF THE CODE AND WHAT WILL HAPPEN WHEN IT STARTS

### File main.tf

In the provider class, we describe the keys and the zone in which we need to run our servers. The cloud service that we will use is also assigned here (**In this case AWS**).

```terraform
provider "aws" {
    access_key = var.access_key
    secret_key = var.secret_key
    region     = "eu-central-1"
}
```
Prescribe the security group by opening **80**, **443**, **22** ports.
```terraform
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
```
Creating a resource to create a new startup configuration used for autoscaling groups.
Creating a resource to create a new startup configuration used for autoscaling groups. In it we write: 'image_id`, which we get using **data** described above, in it we get the latest version of our system image (***Ubuntu*** is installed on the server, so we get exactly its image)
And also the security group that we created above is prescribed.

It also prescribes ***lifecycle***, which will not allow us to put the server in case of any problems or reinstalling or deleting, it will create another one from the beginning, and then it will be destroyed itself.

Immediately we prescribe the use of our script on the server, in the `user_data' parameter.
```terraform
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
```
In the 'aws_autoscaling_group' function, we specify the minimum and maximum number of servers to be created, as well as the vpc zone to be used, in this case we will have 2 zones selected ***eu-centra-1a*** and ***eu-central-1b***.

The load balancer that we will use is also specified.
```terraform
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
```

We need a load balancer to balance the load on our nginx web server, it listens **80** port **TCP**.
```terraform
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
```
Creating subnet management resources that take 2 zones from a region.

```terraform
resource "aws_default_subnet" "default_sub_1" {
    availability_zone = data.aws_availability_zones.avialable.names[0]
}

resource "aws_default_subnet" "default_sub_2" {
    availability_zone = data.aws_availability_zones.avialable.names[1]
}
```
### File output.tf
In ***output.tf***, everything that will be output is specified after using the 'terraform apply' command and creating servers. The file outputs:
+ Latest version **Ubuntu**;
  + Her id as well as her name;
+ As well as the DNS name of the load balancer.
```terraform
output "latest_ubuntu_linux_id" {
    value = data.aws_ami.latest_ubuntu_linux.id
}

output "latest_ubuntu_linux_name" {
    value = data.aws_ami.latest_ubuntu_linux.name
}

output "web_loadbalancer_url" {
    value = aws_elb.balancer.dns_name
}
```
### Bash scripts
The script executes the following commands in the shell on the server:
+ Update;
+ Install nginx;
+ Install dependencies;
+ Starts and restarts nginx;
+ And also copies a small html script I wrote to the directory `/var/www/html`
```bash
#!/bin/bash
# Install and Start Web Server Nginx 
sudo apt -y update 
sudo apt -y install nginx
sudo systemctl status nginx
sudo systemctl start nginx
sudo ufw allow 'Nginx Full'

# Install dependencies
sudo apt -y install curl

# Web site
username=$(whoami)
cd /home/$(whoami)/
myip=$(wget -qO - eth0.me)
touch index.html && echo "<html><body bgclolor="blue"><h2> Build by Power of Terraform v1.1.3 </h2><br><p>server Private IP: $myip </br></p></body></html>" > index.html
cd /var/www/html && sudo cp /home/$(whoami)/index.html /var/www/html

# Restart nginx
sudo systemctl restart nginx
```
