
variable enableprovision {
  description = "enable provision feature"
  type = bool
  default=false
}

variable ghtoken {
  description = "github pat token allowed to create and manage repo"
  type = string
  default="notset"
}

variable ghowner {
  description = "github owner (where to create repo)"
  type = string
  default="notset"
}

variable ghrepo {
  description = "github repo name"
  type = string
  default="notset"
}

variable ghclonepat {
  description="pat token given to you for cloning"
  type=string
  default="notset"
}

variable ghcloneuser {
  description="gh user for cloned repo"
  type=string
  default="notset"
}

variable ghclonerepo {
  description="cloned repo name"
  type=string
  default="notset"
}

