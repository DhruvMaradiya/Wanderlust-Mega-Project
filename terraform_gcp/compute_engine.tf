resource "google_compute_instance" "default" {
  name         = "wanderlust-ce"
  machine_type = "n2-standard-2"
  zone         = var.gcp_zone

  tags = ["wanderlust-compute"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts" 
      size  = 30
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {} 
  }
}

# Fetch current user info
data "google_client_openid_userinfo" "me" {
  
}

# Add your SSH public key for OS Login
resource "google_os_login_ssh_public_key" "sshkey" {
  user = data.google_client_openid_userinfo.me.email
  key  = file("~/.ssh/google_compute_engine.pub")
  project = var.project_id
}
