resource "google_compute_network" "default" {
  name    = "simple-adb-bot"
  project = "the-bot-specialist-dev"
}


resource "google_compute_global_address" "private_ip_alloc" {
  project       = "the-bot-specialist-dev"
  name          = "adb-psa-bot"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 12
  network       = google_compute_network.default.id
  address       = "172.16.0.0"
}

resource "google_service_networking_connection" "vpc_connection" {
  network                 = google_compute_network.default.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  deletion_policy         = "ABANDON"
}
