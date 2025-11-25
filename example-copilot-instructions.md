# Terraform Import Guide

## Quick Reference

### 0. Pre-flight Check (Copilot)
Before starting, ask Copilot to scan the repository and verify that the Terraform resource names in this guide match your actual code structure. This ensures the guide works regardless of how your resources are named or organized:
> "Scan the repository to identify how `aws_instance` and `aws_ebs_volume` resources are defined. Check if the resource names in this guide (currently `aws_instance.ec2` and `aws_ebs_volume.volumes`) match the actual definitions in the codebase. If they differ, update the guide to use the correct resource names."

### 1. Generate Import Commands File
Create `[server-name]-import-commands.txt` with this structure:

```plaintext
# EC2 Instance
terraform import 'aws_instance.ec2["server-key"]' i-instanceid

# EBS Volumes (skip root volume)
terraform import 'aws_ebs_volume.volumes["server-key-0"]' vol-volumeid1
terraform import 'aws_ebs_volume.volumes["server-key-1"]' vol-volumeid2

# Volume Attachments
terraform import 'aws_volume_attachment.attachments["server-key-0"]' /dev/sdb:vol-volumeid1:i-instanceid
terraform import 'aws_volume_attachment.attachments["server-key-1"]' /dev/sdc:vol-volumeid2:i-instanceid

# Verify
terraform plan
```

### 2. Critical Shell Syntax
- ✅ **Single quotes** around entire Terraform resource identifiers
- ✅ **No quotes** around volume attachment strings
- ✅ Volume attachment format: `/dev/device:vol-id:instance-id`

### 3. Expected Post-Import Changes
After import, `terraform plan` typically shows:
- **Tag updates**: Remove AWS migration tags, add organization tags
- **Volume naming**: Standardize names (e.g., "OLD-NAME" → "SERVER-KEY-0")
- **Security groups**: May add/remove groups to match Terraform config
- **Root volume settings**: Usually `delete_on_termination = false` for safety

### 4. Common Issues
**Shell escaping**: Always use single quotes around the entire resource identifier
```bash
# ✅ Correct - single quotes around entire resource identifier
terraform import 'aws_instance.ec2["server"]' i-12345
# ❌ Wrong - no quotes allow shell to interpret brackets
terraform import aws_instance.ec2["server"] i-12345
# ❌ Wrong - backslash escaping (works but unnecessarily complex)
terraform import aws_instance.ec2\[\"server\"\] i-12345
```

**Volume attachments**: Exact format required, no quotes around attachment string
```bash
# ✅ Correct format - no quotes around attachment string  
/dev/sdb:vol-12345:i-67890
# ❌ Wrong - quotes around attachment string cause issues
"/dev/sdb:vol-12345:i-67890"
```

### 5. Safety Checklist
- [ ] Check the [server-name]_details.json
- [ ] Validate ec2 config in ec2.locals.tf for [server-name] is matching the details in [server-name]_details.json
- [ ] Validate terraform import commands file match the terraform config and json
- [ ] Run imports one by one
- [ ] Verify each import succeeds before continuing
- [ ] Run `terraform plan` after all imports
- [ ] Ensure no resources show "destroy and recreate"
- [ ] Validate tag changes are intentional
- [ ] Add lifecycle rules if needed:
```hcl
lifecycle {
  ignore_changes = [launch_template, user_data, ami]
}
```

### 6. Proven Examples (Successfully Tested)
**example-server - Complex Import Example**
```bash
# Instance
terraform import 'aws_instance.ec2["example-server"]' i-0123456789abcdef0

# Volumes
terraform import 'aws_ebs_volume.volumes["example-server-0"]' vol-0123456789abcdef0
terraform import 'aws_ebs_volume.volumes["example-server-1"]' vol-0987654321fedcba0

# Attachments  
terraform import 'aws_volume_attachment.attachments["example-server-0"]' /dev/sdb:vol-0123456789abcdef0:i-0123456789abcdef0
terraform import 'aws_volume_attachment.attachments["example-server-1"]' /dev/sdc:vol-0987654321fedcba0:i-0123456789abcdef0
```

### 7. Import Order
1. EC2 instance first
2. EBS volumes second  
3. Volume attachments last
4. Verify with `terraform plan`

This guide ensures safe, successful imports with minimal disruption.
