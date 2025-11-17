# =============================================================================
# SIMPLE SECURITY GROUP TEMPLATE - WEB APP + RDP SERVER
# =============================================================================
# This simplified template demonstrates our security group methodology
# for just two common use cases: a web application and an RDP server
# =============================================================================

locals {
  # =============================================================================
  # NETWORK DEFINITIONS - Simple and Clear
  # =============================================================================
  # Define your networks once, use them everywhere
  networks = {
    # Your office/corporate networks
    office_network    = "20.0.113.0/24"   # Replace with your office IP range
    vpn_network       = "10.100.0.0/16"    # Replace with your VPN range
    
    # AWS networks
    vpc_network       = "10.0.0.0/16"      # Your AWS VPC
    web_subnet        = "10.0.1.0/24"      # Web application subnet
    management_subnet = "10.0.10.0/24"     # Management/RDP subnet
    
    # Common ranges
    anywhere          = "0.0.0.0/0"        # Internet access
  }

  # =============================================================================
  # SECURITY GROUP RULES - Just What You Need
  # =============================================================================
  security_groups = {
    
    # Web Application Security Group
    "web-app" = {
      description = "Web application server - handles HTTP/HTTPS traffic"
      rules = {
        # Allow web traffic from internet
        "tcp-80-ingress" = {
          description = "Allow HTTP traffic from anywhere"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 80
          to_port     = 80
          cidr_blocks = [local.networks.anywhere]
        },
        "tcp-443-ingress" = {
          description = "Allow HTTPS traffic from anywhere"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_blocks = [local.networks.anywhere]
        },
        
        # Allow management access from office
        "tcp-22-ingress" = {
          description = "Allow SSH from office network"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 22
          to_port     = 22
          cidr_blocks = [
            local.networks.office_network,
            local.networks.vpn_network
          ]
        },
        
        # Allow RDP access from RDP server security group
        "tcp-3389-from-rdp-sg" = {
          description           = "Allow RDP from RDP server security group"
          type                  = "ingress"
          protocol              = "tcp"
          from_port             = 3389
          to_port               = 3389
          source_security_group = "rdp-server"  # Reference to rdp-server security group
        },
        
        # Allow outbound internet access
        "all-egress" = {
          description = "Allow outbound internet access for updates"
          type        = "egress"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          cidr_blocks = [local.networks.anywhere]
        }
      }
    },
    
    # RDP Server Security Group
    "rdp-server" = {
      description = "Windows RDP server - remote desktop access"
      rules = {
        # Allow RDP from office networks only
        "tcp-3389-ingress" = {
          description = "Allow RDP from office and VPN networks"
          type        = "ingress"
          protocol    = "tcp"
          from_port   = 3389
          to_port     = 3389
          cidr_blocks = [
            local.networks.office_network,
            local.networks.vpn_network
          ]
        },
        
        # Allow ping for monitoring
        "icmp-ingress" = {
          description = "Allow ping from office networks"
          type        = "ingress"
          protocol    = "icmp"
          from_port   = -1
          to_port     = -1
          cidr_blocks = [
            local.networks.office_network,
            local.networks.vpn_network
          ]
        },
        
        # Allow outbound internet access
        "all-egress" = {
          description = "Allow outbound internet access"
          type        = "egress"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          cidr_blocks = [local.networks.anywhere]
        }
      }
    }
  }
}

# =============================================================================
# CREATE THE SECURITY GROUPS
# =============================================================================
# This single resource block creates both security groups automatically

resource "aws_security_group" "main" {
  for_each = local.security_groups

  name        = "${each.key}-sg"
  description = each.value.description
  vpc_id      = var.vpc_id  # Your VPC ID

  tags = {
    Name = "${each.key}-sg"
    Type = each.key
  }
}

# =============================================================================
# CREATE ALL THE RULES
# =============================================================================
# This single resource block creates all rules for both security groups

resource "aws_security_group_rule" "rules" {
  for_each = merge([
    for sg_name, sg in local.security_groups : {
      for rule_name, rule in sg.rules :
      "${sg_name}-${rule_name}" => {
        sg_name = sg_name
        rule    = rule
      }
    }
  ]...)

  type              = each.value.rule.type
  from_port         = each.value.rule.from_port
  to_port           = each.value.rule.to_port
  protocol          = each.value.rule.protocol
  description       = each.value.rule.description
  security_group_id = aws_security_group.main[each.value.sg_name].id

  # Handle CIDR-based rules
  cidr_blocks = lookup(each.value.rule, "cidr_blocks", null)

  # Handle security group reference rules (for advanced use)
  source_security_group_id = (
    lookup(each.value.rule, "source_security_group", null) != null
    ? aws_security_group.main[each.value.rule.source_security_group].id
    : null
  )

  # Handle self-referencing rules (for advanced use)
  self = lookup(each.value.rule, "self", false) ? true : null
}

# =============================================================================
# VARIABLES YOU NEED TO PROVIDE
# =============================================================================

variable "vpc_id" {
  description = "The VPC ID where security groups will be created"
  type        = string
  # Example: "vpc-12345678"
}

# =============================================================================
# OUTPUTS - GET THE SECURITY GROUP IDs
# =============================================================================

output "security_group_ids" {
  description = "Security group IDs to use in your servers"
  value = {
    for sg_name, sg in aws_security_group.main : "${sg_name}-sg" => sg.id
  }
}

# =============================================================================
# HOW TO USE THESE SECURITY GROUPS
# =============================================================================

# Example 1: Web Application Server
# resource "aws_instance" "web_server" {
#   ami                    = "ami-12345678"
#   instance_type          = "t3.medium"
#   subnet_id              = "subnet-12345678"
#   vpc_security_group_ids = [aws_security_group.main["web-app"].id]
#   
#   tags = {
#     Name = "Web Server"
#   }
# }

# Example 2: RDP Server
# resource "aws_instance" "rdp_server" {
#   ami                    = "ami-87654321"
#   instance_type          = "t3.medium"
#   subnet_id              = "subnet-87654321"
#   vpc_security_group_ids = [aws_security_group.main["rdp-server"].id]
#   
#   tags = {
#     Name = "RDP Server"
#   }
# }

# =============================================================================
# SUMMARY - What This Template Does
# =============================================================================
# 
# 1. Defines your networks once in a clear, readable way
# 2. Creates security group rules in a structured format
# 3. Automatically generates both security groups
# 4. Automatically creates all the rules
# 5. Provides outputs so you can easily use the security groups
#
# Benefits:
# - Easy to read and understand
# - Easy to modify - just change the rules in the locals
# - Consistent naming and structure
# - No repeated code
# - Self-documenting with clear descriptions
#
# To add more services, just add another entry to the security_groups local!
#
# =============================================================================
