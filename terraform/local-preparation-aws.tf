
locals(
  default_tags          = merge(tomap({ Type = "Splunk", Env = local.env }), var.extra_default_tags, local.splunkit_tags)
  use-elb-private       = (var.create_network_module == "false" || var.force-idx-hecelb-private == "false" ? "false" : "true")
  image_id_al           = (var.enable-al2023 ? data.aws_ssm_parameter.linuxAmiAL2023.value : data.aws_ssm_parameter.linuxAmi.value)
  image_id              = (var.enable-customami ? data.aws_ssm_parameter.linuxAmicustom[0].value : local.image_id_al)
}
