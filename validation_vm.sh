#!/bin/bash
# --- Configuration ---
IMAGE_NAME_FILTER="rhel9-golden"
VM_NAME="rhel9-golden-image-validation-vm-$(date +%s)"
ZONE="us-central1-a"                          
MACHINE_TYPE="e2-medium"                   
PROJECT_ID="xxxx"
SUBNET_NAME="projects/<PROJECT_ID>/regions/us-central1/subnetworks/<subnet_name>"              
SSH_USER="poc" 

   # --- 1. Validate SSH Key String (passed as environment variable) ---
if [ -z "$SSH_PUBLIC_KEY_STRING" ]; then
    echo "Error: SSH_PUBLIC_KEY_STRING environment variable is not set or is empty."
    echo "Please ensure it's passed from GitHub Actions secrets (e.g., secrets.GCP_SSH_PUBLIC_KEY)."
    exit 1
fi
echo "Using SSH public key for user '$SSH_USER' from environment variable."

# --- 2. Get the latest image URI using JSON output and jq ---
echo "Fetching the latest image URI for '$IMAGE_NAME_FILTER' in project '$PROJECT_ID'..."
LATEST_IMAGE_URI=$(gcloud compute images list \
    --project="$PROJECT_ID" \
    --filter="name~'^${IMAGE_NAME_FILTER}'" \
    --sort-by="~creationTimestamp" \
    --limit=1 \
    --format="json" | jq -r '.[0].selfLink')

if [ -z "$LATEST_IMAGE_URI" ] || [ "$LATEST_IMAGE_URI" == "null" ] || [ "$LATEST_IMAGE_URI" == "" ]; then
    echo "Error: Could not find an image URI for '$IMAGE_NAME_FILTER'."
    echo "Please check if an image with that name exists in project '$PROJECT_ID'."
    exit 1
fi
echo "Found latest image URI: $LATEST_IMAGE_URI"

# --- 3. Construct SSH Keys Metadata ---
SSH_KEY_METADATA_VALUE="$SSH_USER:$SSH_PUBLIC_KEY_STRING"

# --- 4. Create the VM ---
echo "-------------------------------------------------------------------"
echo "Creating VM '$VM_NAME' in project '$PROJECT_ID', zone '$ZONE'..."
echo "  Image: $LATEST_IMAGE_URI"
echo "  Machine Type: $MACHINE_TYPE"
echo "  Subnet: $SUBNET_NAME"
echo "  Public IP: Disabled"
echo "  SSH User: $SSH_USER (key provided from secrets)"
echo "-------------------------------------------------------------------"

gcloud compute instances create "$VM_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image="$LATEST_IMAGE_URI" \
    --subnet="$SUBNET_NAME" \
    --no-address \
    --metadata="ssh-keys=$SSH_KEY_METADATA_VALUE" \
    --boot-disk-size=150GB \
