
# Wiki

Most content has been moved and reorganized in wiki
Please see https://github.com/splunk/splunkconf-backup/wiki 

# Legacy readme

Quick and fast guide for deploying a env

by default the terraform is configured for a test env (with minimal cloud cost)  

There are multiple ways of using this :
A) download  and run terraform locally after configuration and directories setup 
B) run in partial VCS mode with only github actions but local terraform
C) run in full VCS mode with github actions and terraform cloud  

Note : the VCS mode is only tested for AWS at the moment but it should work with a few modifications for GCP

VCS mode :
--------

1) log in github with your account
2) clone https://github.com/splunk/splunkconf-backup
3) customize topology
     - go to terraform directory
     - copy topology.txt to topology-local.txt 
     - edit the file with the roles that fit you (the roles need to exist in current dir or instances-extra) (do NOT copy manually the instances file as it would break the github workflow)
     - commit your change to the main branch -> that will automatically position the appropriate instance-xxx.tf files in terraforn directory and the unused in instances-extra directory   (if you run outside github , you may want to call helpers/tftopology.sh manually from top directory)
4) login to terraform cloud
5) create a organization if necessary
6) create a workspace , choose github and give your github cloned repo name here
7) autorize terraform cloud from github (that will prompt you and configure a terraform cloud app inside github where you can restrict access to your repo of choice)
8) create a automation user for terraform cloud in AWS
9) choose a dns subzone (public) that you control (you will delegate the NS record to the ones in AWS) (that is needed so certificate manager will be able to create certificates that belong to you 
10) create global variable configuration (ie variable set) and apply it to workspace with at least the following 
as environment variables
        AWS_ACCESS_KEY_ID (sensitive)
        AWS_SECRET_ACCESS_KEY (sensitive)
        AWS_DEFAULT_REGION   where you want to deploy (like eu-west-3,....) 
as terraform variables
        region-primary   (set to the same region as AWS_DEFAULT_REGION)
        splunkacceptlicense    (see variables.tf) 

        dns-zone-name to the zone name from step above

this is probably enough for testing but you may want to review every variable and customize more here in a second step

11) go to run in terraform and launch a manual run
12) if you are satisfied with the plan , run apply

this will setup all the cloud configuration and deploy splunk with backup and recovery 
however this will not do full provisioning of splunk env itself, jump below for explanation on how to do this 

for local mode :

1) Download the bucket content either to your location (macosx) or to a custom folder on a linux instance

2)
AWS : install AWS SDK for your os  , create a access key from AWS console and configure it locally with aws configure (+set your default region)
GCP : install GCP SDK for your os  , create a service account and key to be configured in it and also set your default region

install terraform
(you could run helper/installrequirement.sh to do it for you under linux)

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
| --- | --- | --- |
| splunkinstanceType | instance type. For a ASG with 1 instance, that become the instance name. Special type = idx (recovery script will automatically detect zone and adapt splunk site for cluster to match AZ) (or idx-site1, idx-site2, idx-site3 if you prefer) (there can be one ASG for all indexer so that cloud redistribute instances to other AZ automatically in case of AZ failure)| Required |
| Name | name that will appear in AWS console (usually same value as splunkinstanceType, do not set for idx) | Optional |
| splunks3backupbucket | cloud bucket (s3/gcs) where backups are stored | Required |
| splunks3installbucket | cloud bucket (s3/gcs) where install files are stored | Required |
| splunks3databucket | cloud SmartStore (s3/gcs) bucket | Optional |
| splunkorg | name used as prefix for base apps | optional but recommended |
| splunkdnszone | this is used to update instance name via dns API (route53,...) in order for the instance to be found by name | Required|
| splunkdnsmode | set this to disabled or lambda if running update via lambda function in AWS| optional, default to inline|
| spunkmode | set this to uf to deploy a uf instead of a full instance| optional |
| splunkacceptlicense | setting passed along to the Splunk initialisation script so Splunk software can start  (see Splunk license at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html)| Required (yes|no) |


Tags to be used for lambda at ASG level (only needed if configured for lambda (AWS))
| Tag | Description | Status |
| --- | --- | --- |
| splunkdnszone | this is used to update instance name via dns API (route53,...) in order for the instance to be found by name | Required|
| splunkdnsnames | name(s) to update in the zone when a autoscaling event occur  | Required|
| splunkdnsprefix| prefix to add to each dns entry| Optional , default to 'lambda-' , set to empty or disabled if you dont want a prefix to be added|



Tags to use for upgrade scenarios and/or backup bootstrap between env (exemple : to restore and auto adapt a prod backup to a test env

| Tag | Description | Status |
| --- | --- | --- |
| splunktargetbinary | splunkxxxx.rpm You may use this to use a specific version on a instance. Use the upgrade script for upgrade scenario if you dont want to destroy/recreate the instance | Optional (recovery version and logic used instead) |
| splunktargetenv | prod, test, lab ….  + This will run the optional helper script appropriate to the ena if existing | Optional |
| splunktargetcm | short name of cluster master (set master_uri= https://$splunktargetcm.$splunkdnszone:8089  under search|indexer cluster app + in outputs for idx discovery)  | Optional but recommended (default to splunk-cm which will effectively set master_uri= https://splunk-cm.$splunkdnszone:8089 ) |
| splunktargetds | short name of deployment server (set targetUri= https://$splunktargetds.$splunkdnszone:8089  in deploymentclient.conf) | Optional |
| splunktargetlm | short name of license server (support only apps where name contain license (should be the case when using base apps), set master_uri= https://$splunktargetlm.$splunkdnszone:8089 in server.conf)| Optional|
| splunkcloudmode | 1 = send to splunkcloud only with provided configuration, 2 = clone to splunkcloud with provided configuration (partially implemeted -> behave like 1 at the moment, 3 = byol or manual config to splunkcloud(default) | Optional |


Tags for inventory and reporting (billing for example)
(not directly used, feel free to adapt to your cloud env inventory preferences)

| Tag | Description | Status |
| --- | --- | --- |
| Vendor | Splunk | Optional |
| Perimeter | Splunk | Optional |
| Type | Splunk | Optional |

GCP specific

| Tag | Description | Status |
| --- | --- | --- |
| splunkdnszoneid | id for dns zone | required if splunkdnszone used|
| numericprojectid | GCP numeric project id | set by GCP|
| projectid | GCP project id | set by GCP|

for dev purpose or if you understand the shortcomings , you can disable autonatic os update (stability and security fixes) as it speed up instance start (avoiding a reboot)
| Tag | Description | Status |
| --- | --- | --- |
| splunkosupdatemode | default="updateandreboot" , other valid value is "disabled" | optional |

multi DS mode specific tags 
1) set the splunktargetbinary to be a tgz version (required to deploy splunk multiple times otherwise we prefer using the os packaging method 

| Tag | Description | Status |
| --- | --- | --- |
| splunkdsnb | number of ds instances to deploy | optional , default to 4 for multi ds|


Advanced, options to splunkconf-init , only set if you know what you do or for dev purposes 

| Tag | Description | Status |
| --- | --- | --- |
| splunksystemd | whether to enable or not systemd for Splunk (auto, systemd or init)  | optional , default to auto  ie autodetect and use when possible|
| splunksystemdservicefile | custom systemd service file  | optional |
| splunksystemdpolkit | 1=deploy inline packaged splunkconf-init version, 2=generate via boot-start (8.1 + required), 3=do not manage (will probably not work correctly as splunk restart will not work from splunk unless deployed via opther method (if using systemd) | optional , default to 1. 2 may break especially on multids case|
| splunkdisablewlm | 0=try to deploy if possible (systemd, version is the one inline at the moment)) 1=disabled | optional , default to 0 (enabled)|
| splunkuser | name of splunk user to use (non priviledge one) | optional , default to splunk (partial support in splunkconf-cloud-receovery at the moment) |
| splunkgroup | name of splunk group to use (non priviledge one) | optional , default to splunk (partial support in splunkconf-cloud-receovery at the moment) |



In dev, partially implemented 

| Tag | Description | Status |
| --- | --- | --- |
| splunkconnectedmode | # 0 = auto (try to detect connectivity, currently fallback to connected) (default if not set) # 1 = connected (set it if auto fail and you think you are connected) # 2 = yum only (may be via proxy or local repo if yum configured correctly) # 3 = no connection, yum disabled | Optional (implemented, except for autodetection)|







 
