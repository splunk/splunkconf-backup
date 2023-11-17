
variable enableprovision {
  description = "enable provision feature"
  type = bool
  default=false
}

variable ghtoken {
  description = "github pat token allowed to create and manage repo"
  type = string
  default=""
}

variable ghowner {
  description = "github owner (where to create repo)"
  type = string
  default=""
}

variable ghrepo {
  description = "github repo name"
  type = string
  default=""
}

variable ghclonepat {
  description="pat token given to you for cloning"
  type=string
  default="patclonenotset"
}

variable ghcloneuser {
  description="gh user for cloned repo"
  type=string
  default="cloneusernotset"
}

variable ghclonerepo {
  description="cloned repo name (do not use empty value)"
  type=string
  default="notset"
}

