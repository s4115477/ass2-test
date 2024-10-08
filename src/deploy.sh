#!/bin/bash
#
# Deploy Foo app - see README.md
#

set -e

echo "Running Section A deployment script"

echo "Testing AWS credentials"
aws sts get-caller-identity

path_to_ssh_key="~/.ssh/id_rsa"

cd infra
echo "Initializing Terraform"
terraform init

echo "Validating Terraform Configuration"
terraform validate

echo "Running terraform apply"
terraform apply

# Get the private IP address of the database
db_private_ip=$(terraform output -json vm_ip_addresses | jq -r '.db.private_ip_address')

# Get the public IP addresses of the app and db instances
app_public_ip=$(terraform output -json vm_ip_addresses | jq -r '.app.public_ip_address')
db_public_ip=$(terraform output -json vm_ip_addresses | jq -r '.db.public_ip_address')

# Generate inventory1.yml for app servers
cat <<EOL > ../ansible/inventory1.yml
app_servers:
  hosts:
    app1:
      ansible_host: '$app_public_ip' # Fill in your "app" instance's public IP address here
EOL

# Generate inventory2.yml for db servers
cat <<EOL > ../ansible/inventory2.yml
db_servers:
  hosts:
    db1:
      ansible_host: '$db_public_ip' # Fill in your "db" instance's public IP address here
EOL

cd ..
cd ansible

# Run the Ansible playbooks
echo "Running Ansible playbook for the database"
ansible-playbook db-playbook.yml -i inventory2.yml --private-key $path_to_ssh_key

echo "Running Ansible playbook for the app"
ansible-playbook app-playbook.yml -i inventory1.yml --private-key $path_to_ssh_key --extra-vars "db_hostname=$db_private_ip"

echo "Deployment completed successfully!"