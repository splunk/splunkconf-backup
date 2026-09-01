# Manage private default route via bastion ENI on ASG launch/terminate events.
# Apache 2.0 Licensed

import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)
env_level = os.environ.get("LOG_LEVEL")
log_level = logging.INFO if not env_level else env_level
logger.setLevel(log_level)

version = "2026090101"

ACTIVE_INSTANCE_STATES = (
    "InService",
    "Pending",
    "Pending:Wait",
    "Pending:Proceed",
    "Warming",
)


def lambda_handler(event, context):
    event_type = event.get("detail-type", "")
    event_region = event["region"]
    asg_name = event["detail"]["AutoScalingGroupName"]
    bastion_asg_name = os.environ["BASTION_ASG_NAME"]

    if asg_name != bastion_asg_name:
        logger.info("Ignoring event for ASG %s", asg_name)
        return {"statusCode": 200, "body": json.dumps("ignored asg")}

    route_table_id = os.environ["ROUTE_TABLE_ID"]
    destination_cidr = os.environ.get("DESTINATION_CIDR", "0.0.0.0/0")

    ec2_client = boto3.client("ec2", region_name=event_region)
    asg_client = boto3.client("autoscaling", region_name=event_region)

    logger.info(
        "lambda %s, asg=%s, event_type=%s, region=%s",
        version,
        asg_name,
        event_type,
        event_region,
    )

    if event_type == "EC2 Instance Launch Successful":
        return handle_launch(
            ec2_client, event, route_table_id, destination_cidr
        )
    if event_type == "EC2 Instance Terminate Successful":
        return handle_terminate(
            ec2_client, asg_client, route_table_id, destination_cidr, bastion_asg_name
        )

    logger.info("Ignoring unsupported event type %s", event_type)
    return {"statusCode": 200, "body": json.dumps("ignored event type")}


def get_primary_eni_id(ec2_client, instance_id):
    reservations = ec2_client.describe_instances(InstanceIds=[instance_id])[
        "Reservations"
    ]
    for reservation in reservations:
        for instance in reservation["Instances"]:
            for interface in instance.get("NetworkInterfaces", []):
                attachment = interface.get("Attachment", {})
                if attachment.get("DeviceIndex") == 0:
                    return interface["NetworkInterfaceId"]
    raise ValueError(f"No primary ENI found for instance {instance_id}")


def route_exists(ec2_client, route_table_id, destination_cidr):
    response = ec2_client.describe_route_tables(RouteTableIds=[route_table_id])
    for route_table in response.get("RouteTables", []):
        for route in route_table.get("Routes", []):
            if route.get("DestinationCidrBlock") == destination_cidr:
                return True
    return False


def should_delete_route(asg_client, asg_name):
    try:
        groups = asg_client.describe_auto_scaling_groups(
            AutoScalingGroupNames=[asg_name]
        )["AutoScalingGroups"]
    except ClientError as exc:
        logger.warning("ASG lookup failed (%s), assuming route should be deleted", exc)
        return True

    if not groups:
        return True

    asg = groups[0]
    if asg.get("DesiredCapacity", 0) == 0:
        return True

    active_instances = [
        instance
        for instance in asg.get("Instances", [])
        if instance.get("LifecycleState") in ACTIVE_INSTANCE_STATES
    ]
    return len(active_instances) == 0


def handle_launch(ec2_client, event, route_table_id, destination_cidr):
    instance_id = event["detail"]["EC2InstanceId"]
    eni_id = get_primary_eni_id(ec2_client, instance_id)

    if route_exists(ec2_client, route_table_id, destination_cidr):
        ec2_client.replace_route(
            RouteTableId=route_table_id,
            DestinationCidrBlock=destination_cidr,
            NetworkInterfaceId=eni_id,
        )
        action = "replace_route"
    else:
        ec2_client.create_route(
            RouteTableId=route_table_id,
            DestinationCidrBlock=destination_cidr,
            NetworkInterfaceId=eni_id,
        )
        action = "create_route"

    logger.info(
        "%s: route_table=%s destination=%s eni=%s instance=%s",
        action,
        route_table_id,
        destination_cidr,
        eni_id,
        instance_id,
    )
    return {
        "statusCode": 200,
        "body": json.dumps(f"{action} successful"),
    }


def handle_terminate(ec2_client, asg_client, route_table_id, destination_cidr, asg_name):
    if not should_delete_route(asg_client, asg_name):
        logger.info(
            "Replacement in progress for %s, keeping route %s",
            asg_name,
            destination_cidr,
        )
        return {
            "statusCode": 200,
            "body": json.dumps("route retained during replacement"),
        }

    try:
        ec2_client.delete_route(
            RouteTableId=route_table_id,
            DestinationCidrBlock=destination_cidr,
        )
        logger.info(
            "delete_route: route_table=%s destination=%s",
            route_table_id,
            destination_cidr,
        )
    except ClientError as exc:
        error_code = exc.response.get("Error", {}).get("Code", "")
        if error_code == "InvalidRoute.NotFound":
            logger.info("Route %s already absent in %s", destination_cidr, route_table_id)
        else:
            raise

    return {
        "statusCode": 200,
        "body": json.dumps("delete_route successful"),
    }
