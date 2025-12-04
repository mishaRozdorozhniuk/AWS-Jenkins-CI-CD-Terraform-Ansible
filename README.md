# Jenkins on AWS with Terraform and Ansible

This project provisions a complete CI environment on AWS using **Terraform** for infrastructure, **Ansible** for configuration management, and **Jenkins** for CI pipelines.

The stack consists of:

- An S3 bucket for remote Terraform state.
- A VPC with public and private subnets.
- A public **Jenkins master** EC2 instance.
- A private **Jenkins worker** EC2 instance (Spot).
- Internet Gateway and NAT Gateway for proper routing.
- Ansible playbook to install Jenkins and Nginx (as reverse proxy).
- Jenkins master + agent configuration and a sample pipeline.

All deployment code (Terraform, Ansible, Jenkinsfile, etc.) is stored in this Git repository.

---

## 1. AWS Infrastructure with Terraform

### 1.1. Prerequisites

- AWS account with permissions to manage:
  - S3, VPC, EC2, IAM, Elastic IPs, Internet/NAT Gateways, Route Tables, Security Groups.
- Local tools installed:
  - Terraform (>= 1.3.x)
  - Ansible
  - SSH client
- Generated SSH key pair on your local machine, e.g.:
  - Public key: `admin_ssh.pub`
  - Private key: `admin_ssh.pem`

The public key path is referenced in Terraform `user_data` and `aws_key_pair`, and the private key path is referenced in `ansible/inventory.ini`.

### 1.2. Remote State S3 Bucket

This project uses **remote state** stored in an S3 bucket to keep Terraform state file centralized and persistent.

- Bucket: `terraform-state-s3-22`
- Region: `eu-central-1`
- Terraform backend configuration (in `terraform.tf`):

```hcl
backend "s3" {
  bucket = "terraform-state-s3-22"
  region = "eu-central-1"
  key    = "terraform-jenkins-ansible/terraform.tfstate"
}
```

Terraform automatically reads and writes the state file `terraform.tfstate` under the `terraform-jenkins-ansible/` prefix in this bucket.

### 1.3. VPC and Networking

Terraform defines the following networking layout in `network.tf` and related files:

1. **VPC** `mykhailo_vpc` with CIDR `10.10.0.0/16`.
2. **Subnets**:
   - Public subnet (for Jenkins master): `10.10.0.0/24`.
   - Private subnet (for Jenkins worker): `10.10.10.0/24`.
3. **Internet Gateway** attached to the VPC for outbound internet from the public subnet.
4. **NAT Gateway** in the public subnet with its own Elastic IP, allowing instances in the private subnet to access the internet.
5. **Route Tables**:
   - Public route table routing `0.0.0.0/0` to the Internet Gateway.
   - Private route table routing `0.0.0.0/0` to the NAT Gateway.

This ensures:

- Jenkins master (public subnet) is directly reachable via the internet over SSH/HTTP.
- Jenkins worker (private subnet) has outbound internet via NAT, but no direct inbound access from the internet.

### 1.4. Security Groups

Two main security groups are defined in `security.tf`:

1. **`jenkins_master_sg`**

   - Inbound rules:
     - TCP 22 (SSH) from `0.0.0.0/0`.
     - TCP 80 (HTTP) from `0.0.0.0/0`.
     - TCP 8080 (Jenkins UI) from `0.0.0.0/0`.
   - Outbound: all traffic allowed.

2. **`jenkins_worker_sg`**
   - Inbound rules:
     - TCP 22 (SSH) only from `jenkins_master_sg` (master can SSH into worker).
   - Outbound: all traffic allowed.

This design exposes only the master to the public internet while protecting the worker in the private subnet.

### 1.5. Key Pair and User Data

Terraform creates an EC2 key pair and injects the public SSH key into instances using `user_data`:

- `aws_key_pair.admin_key` uses the local `admin_ssh.pub`.
- `user-data.sh` is loaded via `templatefile` and:
  - Updates packages.
  - Creates `~ubuntu/.ssh/authorized_keys` on the instance.
  - Appends the provided public key.
  - Sets proper permissions.
  - Installs Java and Python needed for Jenkins and Ansible.

This ensures that you can SSH into the EC2 instances using your local private key.

### 1.6. EC2 Instances (Jenkins Master and Worker)

In `ec2.tf` two instances are defined:

1. **Jenkins Master (on-demand)**

   - Runs in the public subnet.
   - Has a public IP address.
   - Uses `jenkins_master_sg` security group.
   - Uses the shared `admin_ssh` key pair.
   - Cloud-init `user_data` provisions SSH access and base packages.

2. **Jenkins Worker (Spot instance)**
   - Runs in the private subnet.
   - Uses `jenkins_worker_sg` security group.
   - Configured as a **Spot Instance** via `instance_market_options` with `max_price` variable.
   - Uses the same `user_data` script to prepare SSH and base tooling.

Variables such as AMI ID, instance type, SSH key name, spot max price, etc., are defined in `variables.tf` and referenced throughout the configuration.

### 1.7. Terraform Outputs

The project exposes useful values via `outputs.tf`, including:

- `jenkins_master_public_ip` – public IP of the Jenkins master.
- `jenkins_master_private_ip` – private IP of the Jenkins master (for internal references).
- `vpc_id` – ID of the created VPC.
- `jenkins_master_sg_id` – security group ID for the master.

After `terraform apply`, you can retrieve them with:

```bash
terraform output
terraform output jenkins_master_public_ip
terraform output jenkins_master_private_ip
```

### 1.8. Cloud-init user data (SSH + base packages)

Both Jenkins master and worker use the same `user-data.sh` template to configure SSH access and install base packages:

```bash
#!/bin/bash
sudo apt update -y

PUBLIC_KEY="{{ ssh_key_content }}"

HOME_DIR="/home/ubuntu"
USER="ubuntu"

mkdir -p $HOME_DIR/.ssh

echo "$PUBLIC_KEY" >> $HOME_DIR/.ssh/authorized_keys

chmod 700 $HOME_DIR/.ssh
chmod 600 $HOME_DIR/.ssh/authorized_keys
chown -R $USER:$USER $HOME_DIR/.ssh

sudo apt install openjdk-8-jdk -y
sudo apt install python3 -y
```

---

## 2. Jenkins Master Configuration with Ansible

Once the infrastructure is created, Jenkins master is configured using Ansible.

### 2.1. Ansible Inventory

Static inventory is defined in `ansible/inventory.ini`:

```ini
[jenkins_master]
jenkins_master_ip ansible_host=<JENKINS_MASTER_PUBLIC_IP>

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=/path/to/admin_ssh.pem
ansible_python_interpreter=/usr/bin/python3
```

- Replace `<JENKINS_MASTER_PUBLIC_IP>` or update this file using the value from `terraform output`.
- `ansible_user` corresponds to the EC2 AMI default user (Ubuntu in this case).
- `ansible_ssh_private_key_file` is your local private key matching the public key used by Terraform.

### 2.2. Ansible Playbook

The main playbook `ansible/playbook.yml` performs:

1. **System preparation**

   - Update apt packages.
   - Install required dependencies (Java, etc.).

2. **Jenkins installation and setup**

   - Add Jenkins repository and key.
   - Install Jenkins via package manager.
   - Enable and start Jenkins service.

3. **Nginx as Reverse Proxy**
   - Install `nginx`.
   - Configure Nginx as a reverse proxy for Jenkins (typically routing HTTP/HTTPS to Jenkins on port 8080).
   - Ensure Nginx service is enabled and running.

An example command to apply the playbook:

```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

After the playbook completes, Jenkins should be accessible via HTTP on the Jenkins master public IP (through Nginx).

### 2.3. Nginx reverse proxy configuration

The Nginx site configuration is rendered from the Jinja2 template `nginx/nginx.conf.j2` and proxies all HTTP traffic on port 80 to the local Jenkins HTTP port:

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:{{ jenkins_http_port }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 3. Jenkins Configuration and Pipeline

With the Jenkins master up and configured:

1. **Initial Jenkins Setup**

   - Access `http://<JENKINS_MASTER_PUBLIC_IP>/` in a browser.
   - Unlock Jenkins using the initial admin password from the Jenkins master.
   - Install suggested plugins.
   - Create an admin user.

2. **Add Jenkins Worker (Agent)**

   - From the Jenkins UI, configure a new node (agent) corresponding to the private worker EC2 instance.
   - Use SSH credentials (same key pair) or JNLP depending on your setup.
   - Ensure that the master can connect to the worker using its private IP and security group rules.

3. **Pipeline from Previous Project**
   - Create a pipeline job in Jenkins.
   - Point it to the Git repository containing the `Jenkinsfile` from Project Step 2.
   - Run the pipeline and verify that:
     - Build stages execute successfully.
     - The worker node is used as intended (for build/test stages).

---

## 4. Destroying Resources

When you are done with the environment, destroy all Terraform-managed AWS resources to avoid unnecessary costs.

From the root of the project:

```bash
terraform destroy
```

Terraform will:

- Terminate Jenkins master and worker instances.
- Remove NAT and Internet Gateways.
- Delete route tables, subnets, and the VPC.
- Release associated Elastic IP used for NAT.
- Remove the EC2 key pair created by Terraform.

> **Note:** The S3 bucket that stores Terraform state is typically managed separately and is **not** destroyed automatically. You can delete it manually if needed, but only after you no longer require the state file.

### 6.0. Overall architecture diagram

- **Custom diagram of the entire solution (VPC, subnets, NAT, Jenkins master/worker, Ansible, pipeline)**
  ![Custom architecture diagram](img/custom-diagra-of-all.png)

### 6.1. Terraform and EC2 provisioning

- **Terraform init and apply for Jenkins infrastructure**
  ![Terraform init and apply](img/success-terrafrom-init-run-0.png)

- **Jenkins EC2 instances successfully created (master + worker)**
  ![EC2 instances for Jenkins master and worker](img/success-jenkins-instances-created-2.png)

### 6.2. SSH keys and OS verification

- **Extracting public key from the PEM file**
  ![Get public key from PEM](img/get-pub-key-from-pem-1.png)

- **Verifying that the OS on the instance is Ubuntu (expected base image)**
  ![Check OS (Ubuntu)](img/check-that-os-is-what-we-need-ubuntu.png)

- **Connecting to Jenkins master after Terraform created the instance**
  ![SSH to Jenkins master after Terraform](img/success-connect-to-jenkins-master-after-terraform-created-it-4.png)

### 6.3. Ansible configuration and Jenkins availability

- **Successful Ansible playbook run against Jenkins master**
  ![Ansible playbook run](img/success-run-ansible-playbook-inventory-playbook.png)

- **Opening Jenkins in the browser by public IP after Ansible finished (Nginx + Jenkins working)**
  ![Jenkins available over HTTP after Ansible](img/success-open-jenkins-by-ip-after-ansible.png)

### 6.4. Jenkins initial setup and home screen

- **Retrieving initial Jenkins admin password via SSH on the master**
  ![SSH to master to get Jenkins password](img/ssh-to-master-to-get-password-o-jenkins.png)

- **Creating the first Jenkins admin user**
  ![Create Jenkins admin user](img/create-jenkins-user.png)

- **Final Jenkins home screen after initial configuration**
  ![Final Jenkins home screen](img/succes-final-jenkins-home-screen.png)

### 6.5. Jenkins worker (agent) configuration

- **Creating a new Jenkins node for the worker**
  ![Create Jenkins worker node](img/create-new-node-jenkins-worker-6.png)

- **Worker agent successfully connected to Jenkins master**
  ![Worker agent successfully connected](img/check-worker-agent-success-connect.png)

### 6.6. Jenkins credentials and Docker Hub token

- **Adding SSH/PEM credentials to Jenkins**
  ![Add PEM credentials to Jenkins](img/add-credentials-pem-key-to-jenkins-4.png)

- **Overview of all configured credentials (SSH, Git, Docker Hub, etc.)**
  ![All Jenkins credentials overview](img/all-credentials-overview.png)

- **Creating a new Docker Hub token for pushing images from the pipeline**
  ![New Docker Hub token](img/new-dockerhub-tocken-9.png)

- **Credentials successfully created and visible in Jenkins**
  ![Credentials created in Jenkins](img/credentials-created-result-5.png)

### 6.7. Pipeline creation and troubleshooting

- **Creating a new Jenkins pipeline job**
  ![Create new Jenkins pipeline](img/create-new-pipeline-7.png)

- **First pipeline attempt failed due to missing GitLab credentials**
  ![First pipeline attempt failed (GitLab credentials)](img/first-attempt-failed-need-gitlab-cred-8.png)

### 6.8. Final pipeline results

- **Jenkins CI/CD result – view 1 (overall stages)**
  ![Jenkins CI/CD result 1](img/jenkins-cicd-result-1.png)

- **Jenkins CI/CD result – view 2 (additional logs/details)**
  ![Jenkins CI/CD result 2](img/jenkins-cicd-result-2.png)

- **Jenkins CI/CD result – view 3 (full successful pipeline)**
  ![Jenkins CI/CD result 3](img/jenkins-cicd-result-3.png)

---

These screenshots, used in the specified sequence, document the complete lifecycle of the assignment: from Terraform provisioning, through Ansible configuration and Jenkins setup, to CI/CD pipeline execution with a Jenkins master + worker topology.
