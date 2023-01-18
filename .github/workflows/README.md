for TFtopology workklow to run, please go in Github Actions -> Variables and create
TOPOLOGY variable
each line should contain a instance type you want to use
for example std will use instance-std.tf  (that need to exist either in terraform directory or instance-extra directory)

Please only use GitHub variable and not the text file fallback mechanism when running in GitHub as this is much easier for updating repo later on

Note : if you didnt configure anything, the default is one ds with a hf 




