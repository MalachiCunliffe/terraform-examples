#!/usr/bin/env python3
"""
Simple EC2 Details Extractor
Extract details of an EC2 instance given a server name
Default Region: ap-southeast-2

Example Usage:
    # Step 1: Export AWS Credentials to ENV variables (Read only needed for this script)
    export AWS_ACCESS_KEY_ID=AKIA...
    export AWS_SECRET_ACCESS_KEY=...
    export AWS_SESSION_TOKEN=...

    # Get details for a specific server and save to JSON (default)
    python get_ec2_details.py MY-EC2-NAME

    # Get details and display in human-readable format
    python get_ec2_details.py MY-EC2-NAME --human

    # Specify a region
    python get_ec2_details.py MY-EC2-NAME --region us-east-1
"""

import argparse
import boto3
import json
from typing import Dict, List, Optional


def get_volume_details(ec2_client, volume_ids: List[str]) -> Dict[str, Dict]:
    """Get detailed volume information"""
    volume_details = {}
    
    if not volume_ids:
        return volume_details
    
    try:
        response = ec2_client.describe_volumes(VolumeIds=volume_ids)
        for volume in response['Volumes']:
            volume_details[volume['VolumeId']] = {
                'Size': volume['Size'],
                'VolumeType': volume['VolumeType'],
                'State': volume['State'],
                'Encrypted': volume['Encrypted'],
                'Iops': volume.get('Iops', 'N/A'),
                'Throughput': volume.get('Throughput', 'N/A'),
                'SnapshotId': volume.get('SnapshotId', 'N/A'),
                'AvailabilityZone': volume['AvailabilityZone'],
                'CreateTime': volume['CreateTime']
            }
    except Exception as e:
        print(f"Warning: Could not retrieve volume details: {str(e)}")
    
    return volume_details


def get_ec2_details(server_name: str, region: Optional[str] = None) -> Optional[List[Dict]]:
    """Get EC2 instance details by name"""
    
    # Initialize EC2 client with default region ap-southeast-2
    if region:
        ec2 = boto3.client('ec2', region_name=region)
    else:
        ec2 = boto3.client('ec2', region_name='ap-southeast-2')
    
    try:
        # Search for instances by Name tag
        response = ec2.describe_instances(
            Filters=[
                {
                    'Name': 'tag:Name',
                    'Values': [server_name]
                },
                {
                    'Name': 'instance-state-name',
                    'Values': ['running', 'stopped', 'stopping', 'pending', 'shutting-down']
                }
            ]
        )
        
        instances = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instances.append(instance)
        
        if not instances:
            print(f"No EC2 instances found with name: {server_name}")
            return None
        
        if len(instances) > 1:
            print(f"Found {len(instances)} instances with name: {server_name}")
            print("Showing details for all instances:")
        
        # Get volume details for all instances
        all_volume_ids = []
        for instance in instances:
            for bdm in instance.get('BlockDeviceMappings', []):
                if 'Ebs' in bdm:
                    all_volume_ids.append(bdm['Ebs']['VolumeId'])
        
        # Fetch detailed volume information
        volume_details = get_volume_details(ec2, all_volume_ids)
        
        # Add volume details to instances
        for instance in instances:
            instance['VolumeDetails'] = {}
            for bdm in instance.get('BlockDeviceMappings', []):
                if 'Ebs' in bdm:
                    volume_id = bdm['Ebs']['VolumeId']
                    if volume_id in volume_details:
                        instance['VolumeDetails'][volume_id] = volume_details[volume_id]
        
        return instances
        
    except Exception as e:
        print(f"Error retrieving EC2 details: {str(e)}")
        return None


def format_ec2_details(instances: List[Dict]) -> None:
    """Format and display EC2 instance details"""
    
    for i, instance in enumerate(instances, 1):
        if len(instances) > 1:
            print(f"\n{'='*50}")
            print(f"INSTANCE {i} of {len(instances)}")
            print(f"{'='*50}")
        
        # Basic instance information
        print(f"Instance ID: {instance['InstanceId']}")
        print(f"Instance Type: {instance['InstanceType']}")
        print(f"State: {instance['State']['Name']}")
        print(f"Launch Time: {instance['LaunchTime']}")
        print(f"Architecture: {instance['Architecture']}")
        print(f"Platform: {instance.get('Platform', 'Linux/Unix')}")
        
        # Network information
        print(f"\nNetwork Details:")
        print(f"  VPC ID: {instance['VpcId']}")
        print(f"  Subnet ID: {instance['SubnetId']}")
        print(f"  Private IP: {instance['PrivateIpAddress']}")
        if instance.get('PublicIpAddress'):
            print(f"  Public IP: {instance['PublicIpAddress']}")
        print(f"  Private DNS: {instance['PrivateDnsName']}")
        if instance.get('PublicDnsName'):
            print(f"  Public DNS: {instance['PublicDnsName']}")
        
        # Security Groups
        print(f"\nSecurity Groups:")
        for sg in instance['SecurityGroups']:
            print(f"  - {sg['GroupName']} ({sg['GroupId']})")
        
        # Tags
        print(f"\nTags:")
        if 'Tags' in instance:
            for tag in instance['Tags']:
                print(f"  {tag['Key']}: {tag['Value']}")
        else:
            print("  No tags found")
        
        # Storage
        print(f"\nStorage:")
        for bdm in instance.get('BlockDeviceMappings', []):
            if 'Ebs' in bdm:
                device = bdm['DeviceName']
                volume_id = bdm['Ebs']['VolumeId']
                
                # Get detailed volume info if available
                volume_info = instance.get('VolumeDetails', {}).get(volume_id, {})
                if volume_info:
                    size = volume_info.get('Size', 'Unknown')
                    vol_type = volume_info.get('VolumeType', 'Unknown')
                    encrypted = volume_info.get('Encrypted', False)
                    iops = volume_info.get('Iops', 'N/A')
                    throughput = volume_info.get('Throughput', 'N/A')
                    state = volume_info.get('State', 'Unknown')
                    
                    print(f"  {device}: {volume_id}")
                    print(f"    Size: {size} GB")
                    print(f"    Type: {vol_type}")
                    print(f"    State: {state}")
                    print(f"    Encrypted: {encrypted}")
                    if iops != 'N/A':
                        print(f"    IOPS: {iops}")
                    if throughput != 'N/A':
                        print(f"    Throughput: {throughput} MB/s")
                else:
                    print(f"  {device}: {volume_id} (details unavailable)")
            else:
                # Handle non-EBS volumes (like instance store)
                device = bdm['DeviceName']
                print(f"  {device}: Instance store volume")
        
        # Availability Zone
        print(f"\nAvailability Zone: {instance['Placement']['AvailabilityZone']}")
        
        # Key Pair
        if instance.get('KeyName'):
            print(f"Key Pair: {instance['KeyName']}")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="Get EC2 instance details by server name")
    parser.add_argument("server_name", help="Name of the server (EC2 Name tag)")
    parser.add_argument("-r", "--region", help="AWS region (default: ap-southeast-2)")
    parser.add_argument("-o", "--output", help="Output JSON file (default: {server_name}_details.json)")
    parser.add_argument("--human", action="store_true", help="Human-readable output instead of JSON")
    
    args = parser.parse_args()
    
    print(f"Searching for EC2 instance: {args.server_name}")
    if args.region:
        print(f"Region: {args.region}")
    else:
        print(f"Region: ap-southeast-2 (default)")
    
    # Get EC2 details
    instances = get_ec2_details(args.server_name, args.region)
    
    if not instances:
        return
    
    # Auto-generate output filename if not specified
    if not args.output:
        clean_name = args.server_name.replace('/', '_').replace('\\', '_')
        # Default to output/ subfolder for better organization
        args.output = f"output/{clean_name}_details.json"
    
    if args.human:
        # Human-readable output
        format_ec2_details(instances)
    else:
        # Default: JSON output to file
        output_data = {
            "search_query": args.server_name,
            "region": args.region or "ap-southeast-2",
            "timestamp": json.dumps(instances[0]['LaunchTime'], default=str) if instances else None,
            "instance_count": len(instances),
            "instances": instances
        }
        
        # Write to JSON file
        with open(args.output, 'w') as f:
            json.dump(output_data, f, indent=2, default=str)
        
        print(f"EC2 details written to: {args.output}")
        print(f"Found {len(instances)} instance(s)")
        
        # Show summary
        for i, instance in enumerate(instances, 1):
            print(f"  Instance {i}: {instance['InstanceId']} ({instance['State']['Name']})")


if __name__ == "__main__":
    main()
