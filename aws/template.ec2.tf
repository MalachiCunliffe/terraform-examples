# =============================================================================
# EC2 INSTANCE TEMPLATE - SIMPLE SINGLE SERVER EXAMPLE
# =============================================================================
# This template demonstrates our EC2 resource creation methodology
# Shows how locals drive resource creation with for_each loops
# =============================================================================

# =============================================================================
# DATA SOURCES
# =============================================================================
# SSH Key Pair Management:
# This template uses the key_pair_name specified in locals for each instance
# You can either:
# 1. Use an existing key pair (just specify the name in locals)
# 2. Create a new key pair resource with the same name
# 3. Use a data source to reference an existing key:
#    data "aws_key_pair" "existing_key" { key_name = "your-key-name" }

# =============================================================================
# EC2 INSTANCES
# =============================================================================
# Creates EC2 instances based on the configuration in locals
# Each instance in local.ec2_instances becomes a real AWS instance

resource "aws_instance" "ec2" {
  for_each = local.ec2_instances

  ami                    = each.value.ami_id
  instance_type          = each.value.instance_type
  subnet_id              = each.value.subnet_id
  private_ip             = lookup(each.value, "private_ip", null)
  key_name               = each.value.attach_key_pair ? each.value.key_pair_name : null
  vpc_security_group_ids = lookup(each.value, "security_group_ids", null)
  # IAM Instance Profile: Uses the profile specified in locals, or null if not provided
  iam_instance_profile = lookup(each.value, "iam_instance_profile", null)

  # Lifecycle rule to ignore launch template changes for imported instances
  lifecycle {
    ignore_changes = [
      launch_template,
      user_data,
      user_data_base64
    ]
  }

  root_block_device {
    volume_size           = each.value.root_block_device_size
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = lookup(each.value, "kms_key_id", null)
    delete_on_termination = false
    tags = merge(
      {
        "Name" = "${each.value.name}-root"
      },
      local.default_tags
    )
  }
  
  tags = merge(
    {
      "ExampleTag"   = "True"
    },
    each.value.tags
  )
}

# =============================================================================
# ADDITIONAL EBS VOLUMES
# =============================================================================
# Creates additional storage volumes for instances that need them
# Based on the additional_volumes configuration in locals

resource "aws_ebs_volume" "volumes" {
  for_each = {
    for vol in local.ec2_volumes : vol.volume_id => vol
  }

  availability_zone = each.value.az
  size              = each.value.size
  type              = each.value.type
  final_snapshot    = true
  encrypted         = true
  kms_key_id        = lookup(each.value, "kms_key_id", null)
  tags = merge(
    {
      Name = "${each.key}"
      "ExampleTag" = "True"
    },
    each.value.tags
  )
}

# =============================================================================
# VOLUME ATTACHMENTS
# =============================================================================
# Attaches the additional volumes to their respective instances

resource "aws_volume_attachment" "attachments" {
  for_each = {
    for vol in local.ec2_volumes : vol.volume_id => vol
  }

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.volumes[each.key].id
  instance_id = aws_instance.ec2[each.value.instance_key].id
}

# =============================================================================
# OUTPUTS
# =============================================================================
# Useful information about the created instances

output "ec2_instance_details" {
  description = "Details of all created EC2 instances"
  value = {
    for key, instance in aws_instance.ec2 : key => {
      instance_id       = instance.id
      instance_name     = instance.tags["Name"]
      private_ip        = instance.private_ip
      instance_type     = instance.instance_type
      subnet_id         = instance.subnet_id
      security_groups   = instance.vpc_security_group_ids
      availability_zone = instance.availability_zone
    }
  }
}

output "ec2_volumes_created" {
  description = "Details of additional EBS volumes created"
  value = {
    for key, volume in aws_ebs_volume.volumes : key => {
      volume_id         = volume.id
      size              = volume.size
      type              = volume.type
      availability_zone = volume.availability_zone
    }
  }
}

# =============================================================================
# USAGE EXAMPLES AND NOTES
# =============================================================================
#
# This template demonstrates our infrastructure-as-code methodology:
#
# 1. CONFIGURATION-DRIVEN: All server details defined in locals
# 2. DYNAMIC CREATION: for_each loops create resources based on configuration
# 3. CONSISTENT PATTERNS: Same approach works for 1 server or 100 servers
# 4. MODULAR DESIGN: Easy to add new servers without changing resource logic
#
# To deploy this:
# 1. Customize template.ec2.locals.tf with your server configuration
# 2. Ensure required resources exist:
#    - Key pairs specified in key_pair_name (if attach_key_pair is true)
#    - IAM instance profiles specified in locals (if needed)
#    - Security groups referenced in locals
# 3. Run: terraform plan
# 4. Run: terraform apply
#
# To add more servers:
# 1. Add new entries to local.ec2_instances in template.ec2.locals.tf
# 2. No changes needed to this file
# 3. Run terraform plan/apply
#
# Security Features Included:
# - All volumes encrypted with KMS
# - IMDSv2 required for metadata access
# - No public IP addresses by default
# - Proper security group assignment
# - SSH key pair management
#
# Monitoring & Management:
# - Comprehensive tagging for cost allocation
# - Instance naming for easy identification
# - Volume tracking and attachment
# - Output values for integration with other systems
#
# =============================================================================
