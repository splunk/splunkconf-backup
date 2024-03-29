resource "github_repository" "baseapprepo" {
  count = ( var.enableprovision ? 1 : 0 )
  name        = var.ghrepo
  description = "My awesome base app repo"

  visibility = "private"
  has_issues=false
  has_wiki=false
  has_projects=false
  has_discussions=false
  auto_init = true

}

resource "aws_ssm_parameter" "splunkpatjinjarunner" {
  count = ( var.enableprovision ? 1 : 0 )
  name        = "splunkpatjinjarunner"
  description = "pat for runner to attach to custom jinja git"
  type        = "String"
# fixme : create a distinct one
  value       = var.ghtoken
  overwrite   = true

  tags = {
    environment = var.splunktargetenv
  }
}

resource "null_resource" "clonegitfromorigbaseappsjinja" {
  count = ( var.enableprovision ? 1 : 0 )
  #triggers = {
  #  always_run = "${timestamp()}"
  #}
  provisioner "local-exec" {
    command = "[[ -d \"${var.ghclonerepo}\" ]] && rm -r ${var.ghclonerepo};git clone https://${var.ghclonepat}@github.com/${var.ghcloneuser}/${var.ghclonerepo}.git"
  }
}

resource "null_resource" "newgitpopulate" {
  count = ( var.enableprovision ? 1 : 0 )
   provisioner "local-exec" {
     command = "[[ -d \"${var.ghrepo}\" ]] && rm -rf ${var.ghrepo};git clone https://${var.ghtoken}@github.com/${var.ghowner}/${var.ghrepo}.git;cd ${var.ghrepo};cp -rp ../${var.ghclonerepo}/* .;git add --all;git commit -m \"copy files from original repo ${var.ghclonerepo}\";git push origin main"
  }
  depends_on = [null_resource.clonegitfromorigbaseappsjinja,github_repository.baseapprepo]

}

# commit id git show -s| head -1 | cut -d' ' -f 2 

#resource "null_resource" "gitseturl" {
#  count = ( var.enableprovision ? 1 : 0 )
#  #triggers = {
#  #  always_run = "${timestamp()}"
#  #}
#  
#  provisioner "local-exec" {
#    command = "cd ${var.ghclonerepo};git remote set-url origin https://${var.ghtoken}@github.com/${var.ghowner}/${var.ghrepo};git push origin main --force"
# }
# depends_on = [null_resource.clonegitfromorigbaseappsjinja,github_repository.baseapprepo]
#}


