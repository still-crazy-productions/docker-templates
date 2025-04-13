#!/bin/bash
set -euo pipefail

# --- Usage message ---
usage() {
  echo "Usage: sudo $0 --folder=OLD_FOLDER [--rename=NEW_FOLDER]"
  exit 1
}

# --- Parse Arguments ---
OLD_FOLDER=""
NEW_FOLDER=""

for arg in "$@"; do
  case $arg in
    --folder=*)
      OLD_FOLDER="${arg#*=}"
      shift
      ;;
    --rename=*)
      NEW_FOLDER="${arg#*=}"
      shift
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "$OLD_FOLDER" ]; then
  usage
fi

# Default NEW_FOLDER if not provided
if [ -z "$NEW_FOLDER" ]; then
  NEW_FOLDER="$OLD_FOLDER"
fi

# Define paths
STACKS_DIR="/opt/stacks"
VOLUMES_DIR="/opt/volumes"
SERVICE_DIR="${STACKS_DIR}/${OLD_FOLDER}"
NEW_SERVICE_DIR="${STACKS_DIR}/${NEW_FOLDER}"
LOGFILE="/var/log/dockermove_${OLD_FOLDER}.log"

echo "Processing service folder: ${OLD_FOLDER}" | tee -a "$LOGFILE"
echo "New folder name will be: ${NEW_FOLDER}" | tee -a "$LOGFILE"

# --- Step 1: Verify service folder and required files ---
if [ ! -d "$SERVICE_DIR" ]; then
  echo "Error: Service folder $SERVICE_DIR does not exist." | tee -a "$LOGFILE"
  exit 1
fi

COMPOSE_FILE="${SERVICE_DIR}/compose.yaml"
ENV_FILE="${SERVICE_DIR}/.env"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: compose.yaml not found in $SERVICE_DIR" | tee -a "$LOGFILE"
  exit 1
fi

# Backup compose.yaml and .env
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak"
echo "Backup of compose.yaml created." | tee -a "$LOGFILE"

if [ -f "$ENV_FILE" ]; then
  cp "$ENV_FILE" "${ENV_FILE}.bak"
  echo "Backup of .env created." | tee -a "$LOGFILE"
else
  echo "No .env file found; continuing." | tee -a "$LOGFILE"
fi

# --- Step 2: Determine running containers ---
echo "Determining running containers for this service..." | tee -a "$LOGFILE"
cd "$SERVICE_DIR"
RUNNING_CONTAINERS=$(docker compose ps -q || true)
if [ -n "$RUNNING_CONTAINERS" ]; then
  echo "The following containers are running:" | tee -a "$LOGFILE"
  docker compose ps | tee -a "$LOGFILE"
  read -p "Proceed to stop these containers? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborting." | tee -a "$LOGFILE"
    exit 0
  fi
  echo "Stopping containers..." | tee -a "$LOGFILE"
  docker compose down
  # Optionally wait/check for shutdown with a timeout.
else
  echo "No running containers found." | tee -a "$LOGFILE"
fi

# --- Step 3: Process volume folders ---
echo "Processing volume mounts in compose file..." | tee -a "$LOGFILE"
# This assumes volume mounts are defined with lines starting like "- ./something:..."
VOLUME_PATHS=$(grep -Eo '^\s*-\s*\./[^: ]+' "$COMPOSE_FILE" | sed 's/^\s*-\s*\.//' || true)
if [ -z "$VOLUME_PATHS" ]; then
  echo "No relative volume paths detected that need moving." | tee -a "$LOGFILE"
else
  echo "Found volume directories:" | tee -a "$LOGFILE"
  echo "$VOLUME_PATHS" | tee -a "$LOGFILE"
  for vol in $VOLUME_PATHS; do
    SRC_DIR="${SERVICE_DIR}/${vol}"
    DEST_DIR="${VOLUMES_DIR}/${NEW_FOLDER}/${vol}"
    if [ -d "$SRC_DIR" ]; then
      # Capture current permissions and ownership
      perms=$(stat -c "%a" "$SRC_DIR")
      owner=$(stat -c "%U" "$SRC_DIR")
      group=$(stat -c "%G" "$SRC_DIR")
      echo "Volume folder $SRC_DIR: permissions=$perms, owner=$owner, group=$group" | tee -a "$LOGFILE"

      echo "Moving $SRC_DIR to $DEST_DIR" | tee -a "$LOGFILE"
      mkdir -p "$(dirname "$DEST_DIR")"
      mv "$SRC_DIR" "$DEST_DIR"

      # Reapply original ownership and permissions
      chown -R "$owner":"$group" "$DEST_DIR"
      chmod -R "$perms" "$DEST_DIR"
      echo "Reapplied permissions to $DEST_DIR" | tee -a "$LOGFILE"
    else
      echo "Warning: Expected volume folder $SRC_DIR not found." | tee -a "$LOGFILE"
    fi
  done
fi

# --- Step 4: Rename the service folder if needed ---
if [ "$OLD_FOLDER" != "$NEW_FOLDER" ]; then
  echo "Renaming service folder from ${OLD_FOLDER} to ${NEW_FOLDER}..." | tee -a "$LOGFILE"
  mv "$SERVICE_DIR" "$NEW_SERVICE_DIR"
else
  NEW_SERVICE_DIR="$SERVICE_DIR"
fi

# --- Step 5: Update configuration files ---
echo "Updating configuration files with new folder paths..." | tee -a "$LOGFILE"

# 5a. Update references of OLD_FOLDER with NEW_FOLDER in compose.yaml and .env
sed -i "s|${OLD_FOLDER}|${NEW_FOLDER}|g" "${NEW_SERVICE_DIR}/compose.yaml"
if [ -f "${NEW_SERVICE_DIR}/.env" ]; then
  sed -i "s|${OLD_FOLDER}|${NEW_FOLDER}|g" "${NEW_SERVICE_DIR}/.env"
fi

# 5b. Update volume paths in compose.yaml from relative paths to absolute paths.
# For each line like "- ./something:..." replace with "- /opt/volumes/NEW_FOLDER/something:..."
sed -i -E "s|^(\s*-\s*)\./([^:]+)|\1${VOLUMES_DIR}/${NEW_FOLDER}/\2|g" "${NEW_SERVICE_DIR}/compose.yaml"

echo "Configuration files updated." | tee -a "$LOGFILE"

# --- Step 6: Bring up the containers ---
echo "Bringing up containers from the updated configuration..." | tee -a "$LOGFILE"
cd "$NEW_SERVICE_DIR"
docker compose up -d

echo "Service processed successfully." | tee -a "$LOGFILE"