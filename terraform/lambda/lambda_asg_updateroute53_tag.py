# This function process ASG event, get tags from ASG, IPs associated with instances and update one or multiple A entry in the associated zone
# note : this is tested with a public zone, you may need to modify the function if using multiple private zones with the same name

# Apache 2.0 Licensed

import boto3
import logging
import os
import sys
import time
import json

logger = logging.getLogger(name=__name__)
env_level = os.environ.get("LOG_LEVEL")
log_level = logging.INFO if not env_level else env_level
logger.setLevel(log_level)

version="2022040303"

# dont set this too low or the entry could be invalid before being used at all ...
ttl = 300

def lambda_handler(event, context):
    """
    - This lambda function gets triggered for every event in auto scaling group (Instance Launch/Instance Terminate)
    - It first checks if splunkdnsnames and splunkdnszones tags are present in the ASG
    - If Hosted Zone exists it obtains its ID
    - Else do nothing as the zone should have been created by terraform
    - Next it obtains a list of private IPs of all active instances in the autoscaling group which triggered this event
    - If the list contains at least one instance it creates or updates a series of record set named bases on the tags with the private IPs of the instances as A records
    - Else the list is empty (which means the auto scaling group was deleted or doesnt contain any active instance) it wont delete the record set as we prefer to keep a ip while a new instance is created that will override the entry'
    """
    asg_name = event['detail']['AutoScalingGroupName']
    event_region = event['region']
    event_type=event['detail-type']
    print (f"lambda {version}, asg_name={asg_name}, event_type={event_type}, region={event_region}")
    # we try to stay as much as possible in the same region to isolate per region
    ec2_client = boto3.client('ec2',region_name=event_region)
    asg_client = boto3.client('autoscaling',region_name=event_region)
    # for route53, we try to call the API within the region but the zone may be global (and sonehow dependent on us-east-1 at least from a API view)
    r53_client = boto3.client('route53',region_name=event_region)
    (names,domain,prefix)=get_asg_dns_tags(asg_client, asg_name, event_region)
    try:
        sub=ec2_client.describe_subnets(SubnetIds=[event['detail']['Details']['Subnet ID']])['Subnets']
        for subnet in sub:
            event_vpc_id = subnet['VpcId']
        print (f"{event['detail']['Description']} in autoscaling group {asg_name} under VPC ID {event_vpc_id}")
    except Exception as ex:
        # when a ASG downscale, there are 3 events trigering the lambda in a few ms, only one of them has the right info , so we still update route53 correctly (but the ones where describe_subnets is not ready will fail here
        print(f"There is no SubNetID for this event_type (exception={ex}, event_type={event_type}) This may be the case for lifecycle actions")
        #sys.exit("Stopping lambda. describe_subnets incomplete")
        sub=""
        event_vpc_id=""
    hosted_zone_id = get_hosted_zone_id(r53_client,domain, event_vpc_id)
    if hosted_zone_id:
        print (f"HostedZone {domain} under VPC ID {event_vpc_id} in region {event_region} exists in with ID {hosted_zone_id}")
    else:
        print (f"Hosted Zone {domain} Doesn't exists under VPC ID {event_vpc_id} in region {event_region}. please create it")
        return {
        'statusCode': 501,
        'body': json.dumps('lambda autoscale route53 tags not updating du to missing hosted zone')
        }
    # Obtain Private IPs of all active instances in the auto scaling group which triggered this event.
    servers = get_asg_private_ips(asg_client,ec2_client,asg_name)
    print (f"Processing private ips for {names}")
    # If there are Private IPs it means the autoscaling group exists and contains at least one active instances. Create/Update record set in Route53 Hosted Zone.
    if servers:
        print (f"Got servers : Processing private ips for {names}")
        for host in names.split():
            record_set_name = prefix + host + "." + domain
            update_hosted_zone_records(r53_client,hosted_zone_id, record_set_name, ttl, servers)
            print (f"Record set {record_set_name} was created/updated successfully with the following A records {servers}")
    else:
        print (f"No servers : Processing private ips for {names}")
        for host in names.split():
            record_set_name = prefix + host + "." + domain
            print (f"Auto Scaling group {asg_name} does not exist or contain no instances at this time - Trying to delete {record_set_name}")
            #  delete the DNS entry 
            delete_hosted_zone_records(r53_client,hosted_zone_id, record_set_name)
    # Obtain Public IPs of all active instances in the auto scaling group which triggered this event.
    print (f"Processing public ips for {names}")
    servers = get_asg_public_ips(asg_client,ec2_client,asg_name)
    # If there are public IPs it means the autoscaling group exists and contains at least one active instances. Create/Update record set in Route53 Hosted Zone.
    if servers:
        for host in names.split():
            record_set_name = prefix + host + "-ext." + domain
            update_hosted_zone_records(r53_client,hosted_zone_id, record_set_name, ttl, servers)
            print (f"(ext) Record set {record_set_name} was created/updated successfully with the following A records {servers}")
    else:
        for host in names.split():
            record_set_name = prefix + host + "-ext." + domain
            print (f"(ext)Auto Scaling group {asg_name} does not exist or contain no instances with public ip at this time - Trying to delete {record_set_name}")
            #  delete the DNS entry 
            delete_hosted_zone_records(r53_client,hosted_zone_id, record_set_name)
    return {
        'statusCode': 200,
        'body': json.dumps('Executed lambda autoscale route53 tags successfully!')
    }


def get_hosted_zone_id(r53_client,domain, event_vpc_id):
    for hosted_zone in r53_client.list_hosted_zones()['HostedZones']:
        if hosted_zone['Name'] == domain:
            # if you are using private zones with names that are potentially duplicates, you may need to add additional logic below to find the right one
            # r53_client.list_hosted_zones()['HostedZones'][0]['Config']['PrivateZone']
            # if public then no VPCs
            #for vpc in r53_client.get_hosted_zone(Id = hosted_zone['Id'])['VPCs']:
            #    if vpc['VPCId'] == event_vpc_id:
                    return hosted_zone['Id']
    else:
        return False

def get_asg_private_ips(asg_client,ec2_client,asg_name):
    for asg in asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])['AutoScalingGroups']:
        instance_ids = []
        for instance in asg['Instances']:
            if instance['LifecycleState'] == 'InService':
                instance_ids.append(instance['InstanceId'])
        if instance_ids:
            servers = []
            for reservation in ec2_client.describe_instances(InstanceIds = instance_ids)['Reservations']:
                for instance in reservation['Instances']:
                    if instance['State']['Name'] == 'running':
                        servers.append({'Value': instance['PrivateIpAddress']})
            return servers

def get_asg_public_ips(asg_client,ec2_client,asg_name):
    for asg in asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])['AutoScalingGroups']:
        instance_ids = []
        for instance in asg['Instances']:
            if instance['LifecycleState'] == 'InService':
                instance_ids.append(instance['InstanceId'])
        if instance_ids:
            servers = []
            for reservation in ec2_client.describe_instances(InstanceIds = instance_ids)['Reservations']:
                for instance in reservation['Instances']:
                    if instance['State']['Name'] == 'running':
                        servers.append({'Value': instance['PublicIpAddress']})
            return servers

def get_asg_dns_tags(asg_client,asg_name,region):
    r=asg_client.describe_tags(Filters=[{'Name':'auto-scaling-group','Values':[asg_name]},{'Name':'key','Values':['splunkdnszone','splunkdnsnames','splunkdnsprefix']}])
    for tag in r['Tags']:
        k=tag['Key']
        v=tag['Value']
        print (f"key={k},Value={v}")
        if k == 'splunkdnszone':
            zone=v
        elif k == 'splunkdnsnames':
            names=v
        elif k == 'splunkdnsprefix':
            prefix=v
    if 'prefix' in locals():
        if prefix == 'disabled':
            prefix=""
            print (f"OK we have splunkdnsprefix tag set to disabled, setting splunkdnsprefix to be empty")
        else:
            print (f"OK we have splunkdnsprefix={prefix}")
    else:
        # in dev mode or to test the lambda without impacting existing used route53 entries, you can use a prefix here that is added to every ressource created by this function
        prefix="lambda-"
        print (f"splunkdnsprefix tag not found using default value : splunkdnsprefix={prefix}")
    if 'zone' in locals():
        if 'names' in locals():
            print (f"OK we have splunkdnszone={zone} and splunkdnsnames={names}")
        else:
            names="notfound"
            zone="local"
            print (f"this asg doesnt have both tags set : splunkdnszone and splunkdnsnames")
    else:
        names="notfound"
        zone="local"
    if not zone.endswith('.'):

        zone+="."
        #print (f"added . to zone which become {zone} ")
    return [names,zone,prefix]


def update_hosted_zone_records(r53_client,hosted_zone_id, record_set_name, ttl, servers):
    r53_client.change_resource_record_sets(
    HostedZoneId = hosted_zone_id,
    ChangeBatch = {
        'Changes': [
            {
            'Action': 'UPSERT',
            'ResourceRecordSet': {
                'Name': record_set_name,
                'Type': 'A',
                'TTL': ttl,
                'ResourceRecords': servers
            }
        }]
    })
    return

def delete_hosted_zone_records(r53_client,hosted_zone_id, record_set_name):
    for record_set in r53_client.list_resource_record_sets(HostedZoneId = hosted_zone_id)['ResourceRecordSets']:
        if record_set['Name'] == record_set_name:
            try:
                r53_client.change_resource_record_sets(
                HostedZoneId = hosted_zone_id,
                ChangeBatch = {
                    'Changes': [
                        {
                        'Action': 'DELETE',
                        'ResourceRecordSet': record_set
                    }]
                })
                print (f"Record set {record_set_name} removed successfully")
            except:
                print (f"Record set {record_set_name} was already removed by other instance of the lambda function")
            break
    else:
        print (f"Record set {record_set_name} was already removed by other instance of the lambda function")

