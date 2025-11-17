# Terraform Examples

A collection of production-ready Terraform templates demonstrating infrastructure-as-code best practices.

## 📁 Repository Structure

```
terraform-examples/
├── README.md
└── aws/
    ├── template.ec2.tf              # EC2 instance resources
    ├── template.ec2.locals.tf       # EC2 configuration
    └── simple-security-group-template.tf  # Security groups
```

## 🚀 AWS Templates

### EC2 Instance Template
- **Configuration-driven**: All server details defined in locals
- **Dynamic scaling**: Same pattern works for 1 server or 100 servers
- **Security-first**: Encrypted volumes, proper tagging, IAM profiles
- **Flexible options**: SSH keys, security groups, additional volumes

### Security Group Template
- **Structured approach**: Network definitions and rules in locals
- **Dynamic outputs**: Automatically includes all security groups
- **Cross-references**: Examples of security group-to-security group rules
- **Common patterns**: Web servers, RDP servers, management access

## 🛠️ Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd terraform-examples/aws
   ```

2. **Customize the configuration**
   - Edit `template.ec2.locals.tf`
   - Replace all `<REPLACE_WITH_*>` placeholders with your values
   - Uncomment optional features as needed

3. **Deploy**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## 📋 Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate permissions
- Existing VPC, subnets, and supporting AWS resources

## 💡 Key Features

- **Clean separation**: Configuration separate from resources
- **Self-documenting**: Comprehensive comments and examples  
- **Production-ready**: Security best practices included
- **Modular design**: Easy to extend and customize
- **No hardcoded values**: All configuration through locals

## 🔧 Usage Examples

Each template includes detailed usage examples and configuration notes. See the comments within each `.tf` file for specific instructions.

