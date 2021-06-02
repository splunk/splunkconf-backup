# This Makefile create the local bucket structure to be pushed in cloud bucket via terraform
# from the git structure

# FIXME add here copy to recreate bucket structure from git

createbuckets:
i=buckets
mkdir -p $i/bucket-install/install/apps
mkdir -p $i/bucket-install/packaged
# copying apps for bucket install
# Event Timeline is to be downloaded from https://splunkbase.splunk.com/app/4370/#/details
# SHA256 checksum (event-timeline-viz_160.tgz) 8dc7a5cf1faf5d2a64cb2ceae17049070d24f74c381b83f831d0c51ea15a2ffe
# you need this on the MC to have the dashboard viz running 
for j in splunkconf-backup.tar.gz event-timeline-viz_160.tgz
do
  if [ -e ./install/apps/$j ]; then 
    \cp -p ./install/apps/$j "$i/bucket-install/install/apps/"
  else
    echo "ERROR : missing file ./install/apps/$j, please add it and relaunch"
  fi
done
# copying files for bucket install in install
# splunk.secret -> you need to provide it from a splunk deployment (unique to that env)
# user-seed.conf -> to initiate splunk password, you can use splunkconf-init.pl to create it or follow splunk doc 
# splunkconf-aws-recovery.sh is renamed to splunkconf-cloud-recovery.sh, you dont need it unless you rely on user data that reference the old file name
# splunktargetenv are optional script to have custom actions on a specific env when moving between prod and test env (like disabling sending emails or alerts)
for j in splunk.secret user-seed.conf splunkconf-cloud-recovery.sh splunkconf-aws-recovery.sh splunkconf-upgrade-local.sh splunkconf-swapme.pl splunkconf-upgrade-local-precheck.sh splunkconf-upgrade-local-setsplunktargetbinary.sh splunkconf-prepare-es-from-s3.sh user-data.txt user-data-gcp.txt splunkconf-init.pl installes.sh package-systemaws1-for-splunk.tar.gz package-system7-for-splunk.tar.gz package-systemdebian-for-splunk.tar.gz splunktargetenv-for*.sh splunkconf-ds-lb.sh
do
  if [ -e ./install/$j ]; then 
    \cp -p ./install/$j  "$i/bucket-install/install/"
   else
    echo "ERROR : missing file ./install/$j, please read comment in script and evaluate if you need it then relaunch if necessary"
  fi
done
# creating structure for backup bucket
mkdir -p $i/bucket-backup/splunkconf-backup
# creating structure for terraform files
mkdir -p $i/terraform/policy-aws
mkdir -p $i/terraform/scripts-template
mkdir -p $i/terraform-gcp/scripts-template
# scripts template
\cp -fp ../src/splunkconf-aws-terminate-idx.sh $i/terraform/scripts-template/
\cp -fp ../src/splunkconf-aws-terminate-idx.sh $i/terraform-gcp/scripts-template/
# inlined \cp -fp ../splunkconf-backup/aws-update-dns.sh $i/terraform/scripts-template/
# inlined \cp -fp ../splunkconf-backup/gcp-update-dns.sh $i/terraform-gcp/scripts-template/
# terraform tf
chmod a+x terraform/*.sh
chmod a+x terraform-gcp/*.sh
\cp -p ./terraform/*.tf terraform/build-idx-scripts.sh terraform/build-nonidx-scripts.sh terraform/debugtf.sh  "$i/terraform/"
\cp -p ./terraform-gcp/*.tf terraform-gcp/build-idx-scripts.sh terraform-gcp/build-nonidx-scripts.sh terraform-gcp/debugtf.sh  "$i/terraform-gcp/"
rm "$i/terraform/gitlabsplunk.tf"
rm "$i/terraform-gcp/gitlabsplunk.tf"
# policy templates
\cp -rp ./terraform/policy-aws  "$i/terraform/"


