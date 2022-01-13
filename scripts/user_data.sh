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
cd /var/www/html/ && sudo rm index.html
username=$(whoami)
cd /home/$(whoami)/
myip=$(wget -qO - eth0.me)
touch index.html && echo "<html><body bgclolor="blue"><h2> Build by Power of Terraform v1.1.3 </h2><br><p>server Private IP: $myip </br></p></body></html>" > index.html
cd /var/www/html && sudo cp /home/$(whoami)/index.html /var/www/html

# Restart nginx
sudo systemctl restart nginx