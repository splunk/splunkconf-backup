---
layout: default
title: Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection
---
---
layout: default
title: Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection
---
This step is useful when you will want to run terraform in VCS mode

In order to leverage github action workflow to customize terraform template shipped within repository, you can :

browse to https://github.com/splunk/splunkconf-backup/terraform and https://github.com/splunk/splunkconf-backup/terraform/instances-extra, choose and remember all the instances name , you wish to leverage. (make sure it make sense of course)

* clone the original repo (https://github.com/splunk/splunkconf-backup) in your own github account (choose whatever repo name fits you)
* in your cloned repo, clic on "Settings" under the repo then "Secrets and Variables" then "Actions" then select "Variables"
* clic on "New Repository Variable" button (that appeared green on top right)
* name the variable TOPOLOGY
* write each instance name you wish to use (one per line)
* save the variable
* go to Actions menu on top then enable workflow actions
* got to settings for this repo under Actions/General , scrolldown to workflow permissions and change choice to Read and Write permissions, ave
* go back to actions 
* clic on TFTopolocyCI 
* clic on "Run Workflow"

You should see under terraform directory in your cloned repo, list of instance-xxx.tf change to match your topology variablle

In case of issue, you may inspect actions logs from the Actions menu
