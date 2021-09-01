
Quick and fast guide for deploying a env

by default the terraform is configured for a test env (with minimal cloud cost)  

1) Download the bucket content either to your location (macosx) or to a custom folder on a linux instance

2)
AWS : install AWS SDK for your os  , create a access key from AWS console and configure it locally with aws configure (+set your default region)
GCP : install GCP SDK for your os  , create a service account and key to be configured in it and also set your default region

install terraform

3) 
AWS : use terrafom directory
GCP : use terraform-gcp directory

cd into the appropriate terraform directory

4)

terraform init

5) (optional, not needed for a test env but make sense for team work and prod)

create a bucket to store the terraform state and add a tf file to use the remote state in the current directory

6)
a) review all the variables tf files 
by default it is using you local ssh key , change if not the case


b) prod only -> adapt to the right list of components, sizing and integrate with the correct VPC (that is proably already existing)


7)
terraform fmt
terraform validate
terraform plan

At this point nothing was really created

8) (optional but required to have a full env)

change the splunk.secret file to use your own one
change the user-seed.conf (look inside for comments)
default test password is Changed123,

9) ( initially you can start without this step if just want to validate the whole cloud env setup up to splunk component installation)
 prepare the PS base apps
make sure to use the same prefix as defined in the splunkorg variable in terraform

Do NOT package everything, you can deploy later most stuff via traditional Splunk components

package the minimal apps (remove the ._ and .DS files if you are on mac !)
package the minimal tls apps (push this only when you have done the certs preparation, you can start without initially and incremetally add it)
These apps just point the components to the right components (IDX-> CM, other -> DS)
 
10) (optional but recommended for prod)
prepare the custom certs and package them

11) (you can start without for testing but it is required to test CM failover for example)

choose a public dns zone you control (the public zone will allow you to generate real valid certificates, if you want to use private zone, make sure you understand all the additional stuff and work that will be required)
(note : service like Kinesis Firehose do a certification verification so the ELB that receive HEC needs a valid certificate and so a valid domain that you own)

(you could directly create a public zone but that would imply to pay the registrar cost)

choose a prefix that will be the subzone in the cloud provider

create a zone in the public cloud provider like splunkgcp.myzone.com or splunkaws.myzone.com

note the NS

go in your public zone and add NS entries to delegate the sub zone to your public provider

create a test entry in the cloud provider

test resolution from outside

for GCP only note the zoneid

now in the tf variable file, make sure the corresponding variables are adjusted

(optional, aws ) to a terraform import of your existing sub zone

12) create the stuff

terraform apply 
or terraform apply --auto-approve

13) (optional) 
verify in cloud console everything was created
connect to your instance via ssh 

(you can use a custom configuration file to go through a bastion host, in that case you can use the dns name pointing to internal ip but that can only work if the dns is public)

14) when finished testing

terraform destroy 



-----

the recovery script leverage tags which are either statically configured in terraform configuration files (.tf) or via variables

List of tags :

tags are case sensitive

| Tag | Description | Status |
| splunkinstanceType | instance type. For a ASG with 1 instance, that become the instance name.
Special type = idx (recovery script will automatically detect zone and adapt splunk site for cluster to match AZ) (or idx-site1, idx-site2, idx-site3 if you prefer) (there can be one ASG for all indexer so that cloud redistribute instances to other AZ automatically in case of AZ failure)| Required |
| Name | name that will appear in AWS console (usually same value as splunkinstanceType, do not set for idx) | Optional |











 
