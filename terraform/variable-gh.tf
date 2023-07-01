
variable enableprovision {
  description = "enable provision feature"
  type = bool
  default=false
}

variable ghtoken {
  description = "github pat token allowed to create and manage repo"
  type = string
}

variable ghowner {
  description = "github owner (where to create repo)"
  type = string
}

variable ghrepo {
  description = "github repo name"
  type = string
}

variable ghclonepat {
  description="pat token given to you for cloning"
  type=string
}

variable ghcloneuser {
  description="gh user for cloned repo"
  type=string
}

variable ghclonerepo {
  description="cloned repo name"
  type=string
}

