#!/bin/bash
# ----------- config -------------
INSTANCE_NAME="gke-wanderlust-default-pool-47fd410a-84w6"   # << your VM name; never changes
ZONE="us-central1-a"            # << zone you created it in
file_to_find="../backend/.env.docker"
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
current_url=$(sed -n '4p' "$file_to_find")

if [[ "$current_url" != "FRONTEND_URL=\"http://${ipv4_address}:5173\"" ]]; then
  if [[ -f "$file_to_find" ]]; then
    sed -i "s|FRONTEND_URL.*|FRONTEND_URL=\"http://${ipv4_address}:5173\"|" "$file_to_find"
  else
    echo "ERROR: $file_to_find not found."
    exit 1
  fi
fi
