resource "google_compute_firewall" "rules" {
  name        = "wanderlust-firewall"
  network     = "default"
  description = "Allow traffic for SSH, HTTP, HTTPS, Kubernetes, Redis, SMTP, and app ports"

  # Allow SSH, HTTP, HTTPS
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  # Kubernetes NodePort range
  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]  # Kubernetes NodePort services
  }

  # Redis
  allow {
    protocol = "tcp"
    ports    = ["6379"]          # Redis default port
  }

  # SMTP over TLS
  allow {
    protocol = "tcp"
    ports    = ["465"]           # SMTPS for sending mail securely
  }

  # Custom application ports
  allow {
    protocol = "tcp"
    ports    = ["3000-10000"]    # Application-specific ports (frontend/backend APIs)
  }

  # Standard SMTP
  allow {
    protocol = "tcp"
    ports    = ["25"]            # SMTP for mail relay
  }

  # Kubernetes API server
  allow {
    protocol = "tcp"
    ports    = ["6443"]          # Kubernetes API server
  }

  # Source IPs allowed to connect
  source_ranges = ["0.0.0.0/0"]  # From anywhere; in prod you might limit this

  # Apply firewall to VMs with this tag
  target_tags = ["wanderlust-compute"]
}
