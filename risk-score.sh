#!/bin/bash

# --- Configuration ---
# Load environment variables from .env
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Ensure required variables are set
if [ -z "$ORG_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$SNYK_API_TOKEN" ]; then
  echo "Missing required environment variables. Ensure ORG_ID, PROJECT_ID, and SNYK_API_TOKEN are set in .env."
  exit 1
fi

# Snyk API Version (use a recent date)
SNYK_API_VERSION="2024-10-15" # Adjust date as needed

# Wait time in seconds after snyk monitor (adjust based on observation, but reliability is NOT guaranteed)
WAIT_TIME=20

# Define the path to the code you want to scan
# IMPORTANT: Replace this with the actual relative or absolute path
TARGET_CODE_DIR="/Users/pradeepl/source/repos/nodejs-goof"

# --- Prerequisites Check ---
for cmd in jq curl snyk git; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd is not installed. Please install $cmd to run this script."
    exit 1
  fi
done

# --- Script Logic ---

echo "Step 1a: Getting commit hash from $TARGET_CODE_DIR..."
if [ ! -d "$TARGET_CODE_DIR/.git" ]; then
    echo "Error: $TARGET_CODE_DIR is not a git repository."
    exit 1
fi


# Get the commit hash from the target code directory using git -C
COMMIT_HASH=$(git -C "$TARGET_CODE_DIR" rev-parse --short HEAD)
echo "Commit hash: $COMMIT_HASH"

# Step 1: Run snyk monitor
echo "Step 1b: Running snyk monitor..."
snyk monitor --org="$ORG_ID" --project-id="$PROJECT_ID" --target-reference="$COMMIT_HASH" "$TARGET_CODE_DIR"
echo "snyk monitor initiated."

# Step 2: Wait for scan to complete
echo "Step 2: Waiting for $WAIT_TIME seconds for Snyk backend processing (Note: This duration is not guaranteed to be sufficient)..."
sleep $WAIT_TIME

# Step 3
echo "Step 3: Fetching issues and Risk Scores from Snyk API..."

# Initial API URL for issues
NEXT_URL="https://api.snyk.io/rest/orgs/$ORG_ID/issues?project_id=$PROJECT_ID&version=$SNYK_API_VERSION&limit=100" # Use limit=1000 for fewer requests if needed
echo $NEXT_URL
max_risk_score=0
total_issues_found=0

# Loop through paginated results
while [ -n "$NEXT_URL" ] && [ "$NEXT_URL" != "null" ]; do
  echo "Fetching issues from: $NEXT_URL"
  API_RESPONSE=$(curl -s -X GET \
    -H "Authorization: token $SNYK_API_TOKEN" \
    -H "Accept: application/vnd.api+json" \
    "$NEXT_URL")

#   echo $API_RESPONSE
#   read -p "Press Enter to continue..."
  
  # Append response to results.json
  jq -s '.[0] + [.[1]]' results.json <(echo "$API_RESPONSE") > temp_results.json && mv temp_results.json results.json

 
  current_max=$(echo "$API_RESPONSE" | jq '[.data[].attributes.risk.score.value] | max // 0')

  if [ -n "$current_max" ] && [ "$current_max" != "null" ] && [ "$current_max" -gt "$max_risk_score" ]; then
    max_risk_score=$current_max
  fi

   # Get next URL
  NEXT_URL=$(echo "$API_RESPONSE" | jq -r '.links.next // empty')
done

echo "API Fetch Complete. Found $total_issues_found issues across all pages."
echo "Highest Risk Score found: $max_risk_score"

# Step 4: Deployment gate logic
echo "Step 4: Checking deployment gate..."
if (( $(echo "$max_risk_score > $RISK_THRESHOLD" | bc -l) )); then
  echo "❌ Deployment halted. Highest Risk Score ($max_risk_score) exceeds threshold ($RISK_THRESHOLD)."
  exit 1
else
  echo "✅ Deployment approved. Highest Risk Score ($max_risk_score) is within threshold ($RISK_THRESHOLD)."
  exit 0
fi
