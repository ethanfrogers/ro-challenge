#!/usr/bin/env bash
set -e

function get_instance_status {
    echo $(aws ec2 describe-instance-status --instance-ids $1 | jq -r '.InstanceStatuses[0].InstanceStatus.Status')
}

# set some defaults
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-eu-west-1}
VPC_ID="vpc-121b9d74"

# convenience variables
resource_prefix="reactive-ops"
security_group_name="$resource_prefix-sg"
key_name="ethan-ro-key"

echo "Creating resources in $AWS_DEFAULT_REGION"

# check for existance of pre-existing security group
set +e
aws ec2 describe-security-groups --group-names $security_group_name > /dev/null 2>&1
exist_code=$?
set -e

exists="ok"
if [ $exist_code != 0 ]; then
    exists="nope"
fi

sg_id=""
# if we don't have a pre-existing SG, create it
if [ "$exists" != "ok" ]; then
    echo "Security Group $security_group_name does not exist. Creating it."
    create=$(aws ec2 create-security-group --description "Reactive Ops SG" \
        --group-name $security_group_name \
        --vpc-id $VPC_ID)

    sg_id="$(echo $create | jq -r '.GroupId')"

    echo "Created Security Group with ID $sg_id..."
    echo "Adding Security Group Ingress (3000)..."

    # add security group ingress (http)
    aws ec2 authorize-security-group-ingress --group-id $sg_id \
        --protocol tcp \
        --port 3000 \
        --cidr "0.0.0.0/0"
else
    echo "Security Group with name $security_group_name exists. Skipping creation."
    sg_id=$(aws ec2 describe-security-groups --group-names $security_group_name | jq -r '.SecurityGroups[0].GroupId')
fi

if [ "$sg_id" == "" ]; then
    echo "Unable to obtain security group id. aborting!"
    exit 1
fi

# create ec2 instance (attach security group) (userdata)
# AMI ID is for eu-west-1
instance_details=$(aws ec2 run-instances --image-id ami-a61464df \
    --count 1 \
    --instance-type t2.micro \
    --key-name $key_name \
    --security-group-ids $sg_id \
    --user-data file://ignition-config.json)

# get instance id and wait until initialized
instance_id=$(echo $instance_details | jq -r '.Instances[0].InstanceId')
echo "EC2 Instance created with ID $instance_id. Waiting until instance available..."

# TODO(ethanfrogers): could add some kind of timeout here
status=$(get_instance_status $instance_id)
while [ "$status" != "ok" ]; do
    sleep 5
    status=$(get_instance_status $instance_id)
done
echo "Instance $instance_id is available."

# get public dns address and wait until ready
public_dns=$(aws ec2 describe-instances --instance-ids $instance_id | jq -r '.Reservations[0].Instances[0].NetworkInterfaces[0].Association.PublicDnsName')
if [ "$public_dns" == "" ]; then
    echo "there was a problem getting the public dns for instance $instance_id"
    exit 1
fi

echo "Open your browser and navigate to http://$public_dns:3000!"