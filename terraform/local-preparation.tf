# from variables


locals {
  env                   = var.splunktargetenv
  instance-type-indexer = (local.env == "min" ? var.instance-type-indexer-min : var.instance-type-indexer-default)
  instance-type-iuf     = (local.env == "min" ? var.instance-type-iuf-min : var.instance-type-iuf-default)
  instance-type-ihf     = (local.env == "min" ? var.instance-type-ihf-min : var.instance-type-ihf-default)
  instance-type-hf      = (local.env == "min" ? var.instance-type-hf-min : var.instance-type-hf-default)
  instance-type-std     = (local.env == "min" ? var.instance-type-std-min : var.instance-type-std-default)
  instance-type-cm      = (local.env == "min" ? var.instance-type-cm-min : var.instance-type-cm-default)
  instance-type-mc      = (local.env == "min" ? var.instance-type-mc-min : var.instance-type-mc-default)
  instance-type-ds      = (local.env == "min" ? var.instance-type-ds-min : var.instance-type-ds-default)
  instance-type-sh      = (local.env == "min" ? var.instance-type-sh-min : var.instance-type-sh-default)
  instance-type-bastion = var.instance-type-bastion
  # allow to easily disable instance while still configuring the rest (can be useful for testing)
  ds-nb                 = (var.ds-enable ? 1 : 0)
  mc-nb                 = (var.mc-enable ? 1 : 0)
  sh-nb                 = (var.sh-enable ? 1 : 0)
  cm-nb                 = (var.cm-enable ? 1 : 0)
  # short name
  ds = (var.use_elb_ds == true ? var.lbds : var.ds)
  # long names
  mc-dns-name           = "${local.dns-prefix}${var.mc}.${var.dns-zone-name}"
  worker-dns-name       = "${local.dns-prefix}${var.worker}.${var.dns-zone-name}"
  sh-dns-name           = "${local.dns-prefix}${var.sh}.${var.dns-zone-name}"
  idx-dns-name          = "${local.dns-prefix}${var.idx}.${var.dns-zone-name}"
  cm-dns-name           = "${local.dns-prefix}${var.cm}.${var.dns-zone-name}"
  ds-dns-name           = "${local.dns-prefix}${var.ds}.${var.dns-zone-name}"
  std-dns-name          = "${local.dns-prefix}${var.std}.${var.dns-zone-name}"
  hf-dns-name           = "${local.dns-prefix}${var.hf}.${var.dns-zone-name}"
  hfa-dns-name           = "${local.dns-prefix}${var.hf}a.${var.dns-zone-name}"
  hfb-dns-name           = "${local.dns-prefix}${var.hf}b.${var.dns-zone-name}"
  lm-dns-name           = "${local.dns-prefix}${var.lm}.${var.dns-zone-name}"
  iuf-dns-name           = "${local.dns-prefix}${var.iuf}.${var.dns-zone-name}"
  ihf-dns-name           = "${local.dns-prefix}${var.ihf}.${var.dns-zone-name}"

}


# prepare buckets


resource "null_resource" "createbuckets-directories" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "./scripts/createbuckets-directories.sh"
  }
}

resource "null_resource" "build-idx-scripts" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "./scripts/build-idx-scripts.sh idx-site;./scripts/build-idx-scripts.sh idx-site1;./scripts/build-idx-scripts.sh idx-site2;./scripts/build-idx-scripts.sh idx-site3"
  }
  depends_on = [null_resource.createbuckets-directories]
}

resource "null_resource" "build-nonidx-scripts" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "./scripts/build-nonidx-scripts.sh ${var.cm}"
  }
  depends_on = [null_resource.createbuckets-directories]
}

