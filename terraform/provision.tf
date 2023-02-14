locals {
  manager_uri="${local.dns-prefix}${var.cm}.${var.dns-zone-name}"
  license_uri="${local.dns-prefix}${var.lm}.${var.dns-zone-name}"
}

resource "local_file" "ansible_vars_tf" {
  content = <<-DOC
---
- hosts: 127.0.0.1
  vars:
    pass4symmkeyidx: ${local.splunkpass4symmkeyidx}
    pass4symmkeydiscovery: ${local.splunkpass4symmkeyidxdiscovery}
    org: ${var.splunkorg}
    splunkorg: ${var.splunkorg}
    manager_uri: ${local.manager_uri}
    license_uri: ${local.license_uri}
    dns_zone_name: ${var.dns-zone-name}
  tasks:
  - name: create directories for target jinja
    file:
      path: actions-runner/_work/apptest2/{{ item.path }}
      state: directory
      mode: '{{ item.mode }}'
    with_filetree: actions-runner/_work/apptest1
    when: item.state == 'directory'
  - name: apply jinja template
    template:
      src: '{{ item.src }}'
      dest: actions-runner/_work/apptest2/{{ item.path }}
      force: yes
    with_filetree: actions-runner/_work/apptest1
    when: item.state == 'file'


    DOC
  filename = "./ansible_jinja_tf.yml"
}

  provisioner "local-exec" {
    command = "./scripts/copytos3-worker.sh ${aws_s3_bucket.s3_install.id} ${aws_s3_bucket.s3_backup.id}"
    #command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.id}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.id}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.id}/install/ --storage-class STANDARD_IA"
    #command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.arn}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.arn}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.arn}/install/ --storage-class STANDARD_IA"
    #    command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.bucket_regional_domain_name}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.bucket_regional_domain_name}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.bucket_regional_domain_name}/install/ --storage-class STANDARD_IA"
  }
  #depends_on = [null_resource.build-idx-scripts,null_resource.build-cm-scripts,aws_s3_bucket_lifecycle_configuration.s3_install_lifecycle,aws_s3_bucket_lifecycle_configuration.s3_backup_lifecycle,aws_s3_bucket_versioning.s3_install_versioning,aws_s3_bucket_versioning.s3_backup_versioning]
  depends_on = [null_resource.build-idx-scripts, null_resource.build-nonidx-scripts, aws_s3_bucket_lifecycle_configuration.s3_install_lifecycle, aws_s3_bucket_lifecycle_configuration.s3_backup_lifecycle, aws_s3_bucket_versioning.s3_install_versioning, aws_s3_bucket_versioning.s3_backup_versioning,local_file.ansible_vars_tf]
}
