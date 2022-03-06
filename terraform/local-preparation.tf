resource "null_resource" "build-idx-scripts" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "./build-idx-scripts.sh idx-site;./build-idx-scripts.sh idx-site1;./build-idx-scripts.sh idx-site2;./build-idx-scripts.sh idx-site3"
  }
}

resource "null_resource" "build-cm-scripts" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "./build-nonidx-scripts.sh ${var.cm}"
  }
}



resource "null_resource" "bucket_sync" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "./copytos3.sh ${aws_s3_bucket.s3_install.id} ${aws_s3_bucket.s3_backup.id}"
    #command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.id}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.id}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.id}/install/ --storage-class STANDARD_IA"
    #command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.arn}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.arn}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.arn}/install/ --storage-class STANDARD_IA"
    #    command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.bucket_regional_domain_name}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.bucket_regional_domain_name}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.bucket_regional_domain_name}/install/ --storage-class STANDARD_IA"
  }
  #depends_on = [null_resource.build-idx-scripts,null_resource.build-cm-scripts,aws_s3_bucket_lifecycle_configuration.s3_install_lifecycle1,aws_s3_bucket_lifecycle_configuration.s3_install_lifecycle2,aws_s3_bucket_lifecycle_configuration.s3_backup_lifecycle1,aws_s3_bucket_versioning.s3_install_versioning,aws_s3_bucket_versioning.s3_backup_versioning]
  depends_on = [null_resource.build-idx-scripts, null_resource.build-cm-scripts, aws_s3_bucket_lifecycle_configuration.s3_install_lifecycle2, aws_s3_bucket_lifecycle_configuration.s3_backup_lifecycle1, aws_s3_bucket_versioning.s3_install_versioning, aws_s3_bucket_versioning.s3_backup_versioning]
}

