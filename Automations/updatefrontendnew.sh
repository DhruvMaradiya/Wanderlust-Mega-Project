#!/bin/bash
# ----------- config -------------
INSTANCE_NAME="gke-wanderlust-default-pool-47fd410a-d66z"   # VM name (never changes)
ZONE="us-central1-a"            # zone you created it in
file_to_find="../frontend/.env.docker"
# --------------------------------

# get current external IPv4 (empty if VM is stopped)
ipv4_address=$(gcloud compute instances describe "$INSTANCE_NAME" \
               --zone="$ZONE" \
               --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

if [[ -z "$ipv4_address" ]]; then
  echo "ERROR: VM $INSTANCE_NAME has no external IP (stopped?)"
  exit 1
fi

# same sed dance you already use
current_url=$(cat "$file_to_find")

if [[ "$current_url" != "VITE_API_PATH=\"http://${ipv4_address}:31100\"" ]]; then
  if [[ -f "$file_to_find" ]]; then
    sed -i "s|VITE_API_PATH.*|VITE_API_PATH=\"http://${ipv4_address}:31100\"|" "$file_to_find"
    echo "Updated VITE_API_PATH -> http://${ipv4_address}:31100"
  else
    echo "ERROR: $file_to_find not found."
    exit 1
  fi
fi
