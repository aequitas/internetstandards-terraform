terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "aequitas"

    workspaces {
      name = "internetstandards-terraform"
    }
  }
}
