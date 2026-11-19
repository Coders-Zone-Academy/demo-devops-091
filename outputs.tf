output "public_ip_address" {
    # public IP address of my EC2 instance
    value = aws_instance.ec2-ubuntu-web-server.public_ip
}