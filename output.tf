output "latest_ubuntu_linux_id" {
    value = data.aws_ami.latest_ubuntu_linux.id
}

output "latest_ubuntu_linux_name" {
    value = data.aws_ami.latest_ubuntu_linux.name
}

output "web_loadbalancer_url" {
    value = aws_elb.balancer.dns_name
}