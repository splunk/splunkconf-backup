This directory contain :


* tftopology.sh 
This script normally called by GitHub Actions automatically
If not and you want to use it create topology-local.txt file in terraform directory then run this file 

If inside GitHub, please use GitHub variable , see README in workflow directory

* getmycredentials.sh
Ok, TF has run but how do you connect to your instance(s). 
That is not loss as this script will query AWS Secrets manager to help you 

After this , you can use ssh -i mykey-region.priv ec2-user@yourinstancednsname

see TF output for instance dns names
Make sure you added NS records so your subzone is usable btw

 getmycrentials.sh region arn:xxxxxx:xxxxxxxsplunk_admin_pwd      
 the arn is also in TF output, the region is the one you set as variable (us-east-1 if you are using default))

   
