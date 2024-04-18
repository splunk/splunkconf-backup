
locals {
  default_tags          = merge(tomap({ Type = "Splunk", Env = local.env }), var.extra_default_tags)
  #default_tags          = merge(tomap({ Type = "Splunk", Env = local.env }), var.extra_default_tags, local.splunkit_tags)
  use-elb-private       = (var.create_network_module == "false" || var.force-idx-hecelb-private == "false" ? "false" : "true")
  # if al2023 , we ask aws to dynamically resolve AMI ahen launching the instance to get the last AL2023 
  #image_id_al           = (var.enable-al2023 ? "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64" : data.aws_ssm_parameter.linuxAmi.value)
  image_id_al           = (var.enable-al2023 ? data.aws_ssm_parameter.linuxAmiAL2023.value : data.aws_ssm_parameter.linuxAmi.value)
  image_id              = (var.enable-customami ? data.aws_ssm_parameter.linuxAmicustom[0].value : local.image_id_al)
}
