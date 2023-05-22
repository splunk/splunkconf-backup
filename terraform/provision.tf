locals {
  manager_name          = "${local.dns-prefix}${var.cm}.${var.dns-zone-name}"
  license_manager_name  = "${local.dns-prefix}${var.lm}.${var.dns-zone-name}"
  deploymentserver_name = "${local.dns-prefix}${var.ds}.${var.dns-zone-name}"
  smartstore_uri        = "${aws_s3_bucket.s3_data.id}/smartstore"
  base-apps-jinja-dir   = var.base-apps-jinja-dir
  base-apps-target-dir  = var.base-apps-target-dir
}

resource "local_file" "ansible_vars_tf" {
  content  = <<-DOC
---
- hosts: 127.0.0.1
  vars:
    pass4symmkeyidx: ${local.splunkpass4symmkeyidx}
    pass4symmkeyidxdiscovery: ${local.splunkpass4symmkeyidxdiscovery}
    pass4symmkeyshc: ${local.splunkpass4symmkeyshc}
    org: ${var.splunkorg}
    splunkorg: ${var.splunkorg}
    manager_name: ${local.manager_name}
    license_manager_name: ${local.license_manager_name}
    deploymentserver_name: ${local.deploymentserver_name}
    smartstore_uri: ${local.smartstore_uri}
    smartstore_site_number: ${var.splunksmartstoresitenumber}
    dns_zone_name: ${var.dns-zone-name}
    splunk_ssh_key_arn: ${module.ssh.splunk_ssh_key_arn}
  tasks:
  - name: create directories for target jinja
    file:
      path: ${var.base-apps-target-dir}/{{ item.path }}
      state: directory
      mode: '{{ item.mode }}'
    with_filetree: ${var.base-apps-jinja-dir}
    when: item.state == 'directory'
  - name: apply jinja template
    template:
      src: '{{ item.src }}'
      dest: ${var.base-apps-target-dir}/{{ item.path }}
      force: yes
    with_filetree: ${var.base-apps-jinja-dir}
    when: item.state == 'file'
  - name: package apps
    command: "/bin/bash ./scripts/createpackaged.sh ${var.splunkorg} ${var.base-apps-target-dir} packaged 0 disabled sh idx cm mc ds std"
  - name: sync packaged to s3 install
    command: "aws s3 sync packaged ${local.s3_install_s3uri}/packaged" 
  - name: get credentials
    tags:
      - credentials
    command: "/bin/bash ${local.helper-getmycredentials}"
    args:
      chdir: "../helpers"
    DOC
  filename = "./ansible_jinja_tf.yml"
}

resource "local_file" "ansible_jinja_byhost_tf" {
  content  = <<-DOC
---
- hosts: ALL
  vars:
    org: ${var.splunkorg}
    splunkorg: ${var.splunkorg}
    splunk_ssh_key_arn: ${module.ssh.splunk_ssh_key_arn}
  tasks:
  - name: apply packaged apps
    command: "/bin/bash ./scripts/applypackaged.sh ${var.splunkorg} ${var.base-apps-target-dir} packaged 0 disabled sh idx cm mc ds std"
    DOC
  filename = "./ansible_jinja_byhost_tf.yml"
}

resource "local_file" "ansible_inventory" {
  content  = <<-DOC
all:
  hosts:
    sh:
      ansible_host: ${local.sh-dns-name}
    cm:
      ansible_host: ${local.sh-dns-name}
    ds:
      ansible_host: ${local.sh-dns-name}
    mc:
      ansible_host: ${local.sh-dns-name}
  vars:
    ansible_user: ec2-user
    ansible_ssh_private_key_file: ./mykey-${var.region-primary}.priv
    DOC
  filename = "./inventory.yaml"
}


resource "null_resource" "bucket_sync_worker" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "./scripts/copytos3-worker.sh ${aws_s3_bucket.s3_install.id} ${aws_s3_bucket.s3_backup.id}"
  }
  depends_on = [null_resource.build-idx-scripts, null_resource.build-nonidx-scripts, aws_s3_bucket_lifecycle_configuration.s3_install_lifecycle, aws_s3_bucket_lifecycle_configuration.s3_backup_lifecycle, aws_s3_bucket_versioning.s3_install_versioning, aws_s3_bucket_versioning.s3_backup_versioning, local_file.ansible_vars_tf, local_file.ansible_jinja_byhost_tf, local_file.ansible_inventory]
}
