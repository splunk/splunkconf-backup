resource "null_resource" "bucket_sync" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.id}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.id}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.id}/install/ --storage-class STANDARD_IA"
    #command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.arn}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.arn}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.arn}/install/ --storage-class STANDARD_IA"
    #    command = " aws s3 sync ./packaged s3://${aws_s3_bucket.s3_install.bucket_regional_domain_name}/packaged/ --storage-class STANDARD_IA; aws s3 sync ./splunkconf-backup s3://${aws_s3_bucket.s3_backup.bucket_regional_domain_name}/splunkconf-backup/ --storage-class STANDARD_IA; aws s3 sync ./install s3://${aws_s3_bucket.s3_install.bucket_regional_domain_name}/install/ --storage-class STANDARD_IA"
  }
}

