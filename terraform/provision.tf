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
- hosts: all
  become: yes
  become_user: splunk
  vars:
    org: ${var.splunkorg}
    splunkorg: ${var.splunkorg}
    splunk_ssh_key_arn: ${module.ssh.splunk_ssh_key_arn}
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
  tasks:
  - name: Download packaged file for apps from s3 install 
    amazon.aws.aws_s3:
      bucket: ${local.s3_install_bucket}
      mode: get
      object: "packaged/{{ inventory_hostname }}/initialapps.tar.gz"
      dest: "/opt/splunk/var/install/initialapps.tar.gz"
    register: getresult
  - debug: 
      msg="{{ getresult.msg }}" 
    when: getresult.changed
  - name: Unarchive a file that needs to be downloaded (added in 2.0)
    ansible.builtin.unarchive:
      src: "/opt/splunk/var/install/initialapps.tar.gz"
      dest: /opt/splunk/etc/apps/
      remote_src: yes
    DOC
  filename = "./ansible_jinja_byhost_tf.yml"
}
#  - name: apply packaged apps
#    command: "/bin/bash ./scripts/applypackaged.sh ${var.splunkorg} ${var.base-apps-target-dir} packaged 0 disabled sh idx cm mc ds std"

resource "local_file" "ansible_inventory" {
  content  = <<-DOC
all:
  hosts:
    sh:
      ansible_host: ${local.sh-dns-name}
    cm:
      ansible_host: ${local.cm-dns-name}
    ds:
      ansible_host: ${local.ds-dns-name}
    mc:
      ansible_host: ${local.mc-dns-name}
  vars:
    ansible_user: ec2-user
    ansible_ssh_private_key_file: ./mykey-${var.region-primary}.priv
    DOC
  filename = "./inventory.yaml"
}

resource "local_file" "splunk_ansible_inventory" {
  content  = <<-DOC
---
- hosts: 127.0.0.1
  gather_facts: false
  vars:
    hostsh: ${local.sh-dns-name}
    hostds: ${local.ds-dns-name}
    hostcm: ${local.cm-dns-name}
    hostidx: ${local.idx-dns-name}
    hostmc: ${local.mc-dns-name}
    hosthf: ${local.hf-dns-name}
    hoststd: ${local.std-dns-name}
    hostlm: ${local.lm-dns-name}
    hostworker: ${local.worker-dns-name}
    region: ${var.region-primary}
  tasks:
  tasks:
    - name: Fetch priv key via SSM
      aws_ssm_parameter:
        region: ${var.region-primary}
        names: "splunk_ssh_key"
      register: splunk_ssh_key_ssm

    - name: Display ssh key 
      debug:
        var: splunk_ssh_key_ssm.parameters[0].value
    - name: Store key in file so we can reuse
      copy:
        content: "{{ splunk_ssh_key_ssm.parameters[0].value }}"
        dest: "./mykey-${var.region-primary}.priv"
    - name: create ansible inventory with splunk ansible roles
      template:
        src: "j2/splunk_ansible_inventory_template.j2"
        dest: "j2/splunk_ansible_inventory.yml"
        mode: 0640

    DOC
  filename = "./splunk_ansible_inventory_create.yml"
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
