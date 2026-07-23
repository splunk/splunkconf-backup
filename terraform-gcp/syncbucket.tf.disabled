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
    command = "./copytogcs.sh ${google_storage_bucket.gcs_install.url} ${google_storage_bucket.gcs_backup.url}"
  }
  depends_on = [null_resource.build-idx-scripts, null_resource.build-cm-scripts]
}

