# Quick gcloud commands for ConvoBridge GPU demo (copy/paste).
# Run from a PC with Google Cloud SDK installed, or use Cloud Shell.

# 0) Login / project
# gcloud auth login
# gcloud config set project YOUR_PROJECT_ID

# 1) Enable Compute
gcloud services enable compute.googleapis.com

# 2) Create T4 GPU VM (Deep Learning image)
gcloud compute instances create convobridge-gpu \
  --zone=us-central1-a \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --maintenance-policy=TERMINATE \
  --boot-disk-size=100GB \
  --image-family=pytorch-latest-gpu \
  --image-project=deeplearning-platform-release \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=convobridge

# 3) Firewall for API
gcloud compute firewall-rules create allow-convobridge-8000 \
  --allow=tcp:8000 \
  --target-tags=convobridge \
  --source-ranges=0.0.0.0/0 \
  --description="ConvoBridge FastAPI" || true

# 4) Public IP
gcloud compute instances describe convobridge-gpu \
  --zone=us-central1-a \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"

# 5) SSH
# gcloud compute ssh convobridge-gpu --zone=us-central1-a

# 6) STOP when demo ends (saves credits)
# gcloud compute instances stop convobridge-gpu --zone=us-central1-a
