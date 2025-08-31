#!/bin/sh
#
# Daily check script for conditional Docker image rebuild & push.
# Logic:
#   - Runs every day (via cron).
#     0 5 * * *   <path>/auto_rebuild.sh
#   - Reads timestamp of the last rebuild from a file.
#   - If more than N days have passed, rebuild & push image.
#   - Otherwise exit quietly.

set -e

# Change working directory to the directory where this script is located.
cd "$(dirname "$0")" || exit 1

# Load variables from .env
. ./.env_autorebuild

# Logging function with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Get current timestamp (seconds since epoch)
current_ts=$(date +%s)

# Read last timestamp or assume "never run" (0)
if [ -f "$STAMP_FILE" ]; then
    last_ts=$(cat "$STAMP_FILE")
else
    last_ts=0
fi

# Calculate difference in days
diff_days=$(( (current_ts - last_ts) / 86400 ))

# Compare as integers: rebuild only if diff_days >= threshold
if [ "$diff_days" -ge "$DAYS_THRESHOLD" ]; then
    log "Starting Docker rebuild process..."

    # --- BUILD/UPLOAD  ---
    log "Building the image $IMAGE_NAME"
    docker buildx build --pull --no-cache -t $IMAGE_NAME .

    # Docker Hub login
    log "Logging into Docker Hub"
    echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin

    # Tag the Docker image
    log "Tagging image: $DOCKERHUB_USER/$IMAGE_NAME:$IMAGE_TAG"
    docker tag "$IMAGE_NAME" "$DOCKERHUB_USER/$IMAGE_NAME:$IMAGE_TAG"

    # Push the image to Docker Hub
    log "Pushing image to Docker Hub"
    docker push "$DOCKERHUB_USER/$IMAGE_NAME:$IMAGE_TAG"

    # Save the new timestamp
    echo "$current_ts" > "$STAMP_FILE"
    log "Rebuild completed successfully"

else
    log "Skipping rebuild - only $diff_days days since last rebuild (threshold: $DAYS_THRESHOLD days)"
fi
