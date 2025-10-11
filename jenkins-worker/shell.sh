# ---------- config ----------
WORKER_NAME="jenkins-worker"
ZONE="us-central1-a"          # pick your preferred zone
MACHINE_TYPE="e2-standard-2"  # 2 vCPU / 8 GB
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
BOOT_DISK_SIZE="30"
TAGS="jenkins-worker,http-server,https-server"
# ------------------------------

gcloud compute instances create $WORKER_NAME \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --boot-disk-size=$BOOT_DISK_SIZE \
  --image-family=$IMAGE_FAMILY \
  --image-project=$IMAGE_PROJECT \
  --tags=$TAGS \
  --scopes=cloud-platform \
  --metadata=startup-script='#!/bin/bash
set -e
apt-get update -y
apt-get install -y openjdk-17-jre docker.io
usermod -aG docker ubuntu
# install gcloud kubectl (already on master, but handy here)
apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
systemctl enable --now docker'