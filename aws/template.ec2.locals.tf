# =============================================================================
# EC2 LOCALS TEMPLATE - SIMPLE SINGLE SERVER EXAMPLE
# =============================================================================
# This template demonstrates our EC2 configuration methodology
# for a single server to show the structure and approach
# =============================================================================

locals {
  # =============================================================================
  # EC2 INSTANCE DEFINITIONS
  # =============================================================================
  # Benefits:
  # - Centralized server configuration in structured format
  # - Easy to add new servers by copying the pattern
  # - Consistent configuration across all instances
  # - Support for optional parameters with defaults
  # - Clear documentation of each server's purpose

  ec2_instances = {
    # Example Web Server
    "web-server-01" = {
      # Basic Configuration
      environment            = "prod"                    # Environment tag
      name                   = "WebServer01"             # Display name
      instance_type          = "t3.medium"               # AWS instance size
      
      # Network Configuration
      ami_id                 = "<REPLACE_WITH_YOUR_AMI_ID>"     # e.g., "ami-0c02fb55956c7d316" (Amazon Linux 2)
      subnet_id              = "<REPLACE_WITH_YOUR_SUBNET_ID>"  # e.g., "subnet-12345abcde"
      private_ip             = "192.0.2.10"              # Optional: specific IP (remove for auto-assign)
      
      # Security & Access
      attach_key_pair        = false                     # Whether to attach SSH key pair
      # key_pair_name          = "<REPLACE_WITH_YOUR_KEY_PAIR_NAME>"  # Name of the key pair to use (if attach_key_pair is true)
      security_group_ids     = [
        "web-app",                                        # Reference to security group from simple-security-group-template.tf
        "<REPLACE_WITH_MONITORING_SG>"                    # Add your monitoring security group ID or name
      ]
      
      # Storage Configuration
      # kms_key_id             = "<REPLACE_WITH_YOUR_KMS_KEY_ARN>"        # Optional: e.g., "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
      root_block_device_size = 20                        # Root volume size in GB
      
      # IAM Configuration (recommended for AWS API access)
      # iam_instance_profile   = "<REPLACE_WITH_YOUR_IAM_INSTANCE_PROFILE>"  # e.g., "ec2-default-role"
      
      # Tags for the instance
      tags = {
        "Application"          = "WebServer"
        "Owner"               = "WebTeam"
        "Backup"              = "Daily"
        "MaintenanceWindow"   = "Sunday-2AM"
        "CostCenter"          = "IT-Web"
      }
      
      # Additional EBS Volumes (optional)
      additional_volumes = [
        {
          device_name = "/dev/sdf"                       # Device mount point
          volume_size = 100                              # Volume size in GB
          volume_type = "gp3"                            # Volume type (gp3, gp2, io1, etc.)
          az          = "<REPLACE_WITH_YOUR_AZ>"         # e.g., "us-east-1a"
          tags = {
            "Name"    = "WebServer01-data"
            "Purpose" = "Application Data"
          }
        },
        {
          device_name = "/dev/sdg"
          volume_size = 50
          volume_type = "gp3"
          az          = "<REPLACE_WITH_YOUR_AZ>"         # e.g., "us-east-1a"
          tags = {
            "Name"    = "WebServer01-logs"
            "Purpose" = "Log Storage"
          }
        }
      ]
    }

    # Example: How to add a second server (commented out for single server demo)
    # "db-server-01" = {
    #   environment            = "prod"
    #   name                   = "DatabaseServer01"
    #   instance_type          = "r5.large"
    #   ami_id                 = "<REPLACE_WITH_YOUR_AMI_ID>"
    #   subnet_id              = "<REPLACE_WITH_YOUR_SUBNET_ID>"
    #   attach_key_pair        = false
    #   key_pair_name          = "<REPLACE_WITH_YOUR_KEY_PAIR_NAME>"
    #   security_group_ids     = ["<REPLACE_WITH_DB_SG>", "<REPLACE_WITH_MONITORING_SG>"]
    #   kms_key_id             = "<REPLACE_WITH_YOUR_KMS_KEY_ARN>"
    #   iam_instance_profile   = "<REPLACE_WITH_YOUR_IAM_INSTANCE_PROFILE>"
    #   root_block_device_size = 50
    #   tags = {
    #     "Application" = "Database"
    #     "Owner"      = "DBA-Team"
    #   }
    #   additional_volumes = [
    #     {
    #       device_name = "/dev/sdf"
    #       volume_size = 500
    #       volume_type = "io1"
    #       az          = "<REPLACE_WITH_YOUR_AZ>"
    #       tags = {
    #         "Name" = "DatabaseServer01-data"
    #       }
    #     }
    #   ]
    # }
  }

  # =============================================================================
  # VOLUME PROCESSING LOGIC
  # =============================================================================
  # This automatically processes all additional volumes from all instances
  # and creates a flat list for the aws_ebs_volume resource to use
  
  ec2_volumes = flatten([
    for instance_key, instance in local.ec2_instances : [
      for idx, vol in lookup(instance, "additional_volumes", []) : {
        instance_key   = instance_key                    # Which server this volume belongs to
        volume_index   = idx                             # Index of this volume for the server
        volume_id      = "${instance_key}-${idx}"        # Unique ID for this volume
        device_name    = vol.device_name                 # Where to mount (/dev/sdf, etc.)
        kms_key_id     = lookup(instance, "kms_key_id", null) # KMS key from server config (optional)
        size           = vol.volume_size                 # Size in GB
        type           = vol.volume_type                 # Volume type (gp3, io1, etc.)
        az             = vol.az                          # Availability zone
        tags           = vol.tags                        # Volume-specific tags
      }
    ]
  ])

  # =============================================================================
  # DEFAULT CONFIGURATION VALUES
  # =============================================================================
  # These provide sensible defaults and can be overridden per instance
  
  default_tags = {
    "Environment"   = "production"
    "ManagedBy"     = "Terraform"
    "Project"       = "WebApplication"
    "Team"          = "Infrastructure"
  }
  
  # Default IAM instance profile (can be overridden per server)
  default_iam_instance_profile = "default-ec2-role"
}

# =============================================================================
# CONFIGURATION NOTES
# =============================================================================
# 
# To customize this template for your environment:
# 
# 1. Replace all <REPLACE_WITH_*> placeholders with your actual values:
#    - AMI IDs with your organization's approved AMIs
#    - Subnet IDs to match your VPC subnets  
#    - Security group IDs/names to match your security groups
#    - KMS key ARNs for your encryption keys (optional)
#    - Availability zones to match your region
# 2. Customize tags to match your organization's tagging strategy
# 3. Create the required supporting resources (key pairs, IAM roles, security groups)
# 
# To add more servers:
# 1. Copy the "web-server-01" block
# 2. Change the key name (e.g., "app-server-01")
# 3. Modify the configuration values as needed
# 4. The volumes and resources will be created automatically
# 
# Optional Features:
# - Remove "private_ip" to use auto-assigned IPs
# - Remove "additional_volumes = []" if no extra storage needed
# - Add custom IAM instance profile per server if needed
# - Customize tags per server as required
# 
# =============================================================================
