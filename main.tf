variable "domains" {
  default = [
    "dashboard.internet.nl",
    "acc.dashboard.internet.nl",
  ]
}

variable "uptimerobot_api_key" {}

provider "uptimerobot" {
  api_key = var.uptimerobot_api_key
}

data "uptimerobot_account" "account" {}

data "uptimerobot_alert_contact" "default_alert_contact" {
  friendly_name = "${data.uptimerobot_account.account.email}"
}

resource "uptimerobot_monitor" "availability" {
  count         = length(var.domains)
  friendly_name = format("availability %s", var.domains[count.index])
  type          = "http"
  url           = format("https://%s", var.domains[count.index])
  # pro allows 60 seconds
  interval = 300

  alert_contact {
    id = "${data.uptimerobot_alert_contact.default_alert_contact.id}"
  }
}

resource "uptimerobot_monitor" "ipv6_availability" {
  count         = length(var.domains)
  friendly_name = format("IPv6 availability %s", var.domains[count.index])
  type          = "http"
  url           = format("https://ipv6.%s", var.domains[count.index])
  # pro allows 60 seconds
  interval = 600

  alert_contact {
    id = "${data.uptimerobot_alert_contact.default_alert_contact.id}"
  }
}

resource "uptimerobot_status_page" "main" {
  friendly_name = "Internet.nl Dashboard"
  custom_domain = "status.dashboard.internet.nl"
  sort          = "down-up-paused"
  monitors = concat(
    uptimerobot_monitor.availability.*.id,
    uptimerobot_monitor.ipv6_availability.*.id,
  )
}

output "status_url" {
  value = uptimerobot_status_page.main.standard_url
}
