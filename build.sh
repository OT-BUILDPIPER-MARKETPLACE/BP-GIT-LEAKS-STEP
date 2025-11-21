#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/mi-functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source /opt/buildpiper/shell-functions/getDataFile.sh

git config --global --add safe.directory "$(pwd)"

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

# Clone repo if not already there
if [[ ! -d "$CODEBASE_LOCATION" && -n "$GIT_REPO_URL" ]]; then
  echo "[INFO] Cloning $GIT_REPO_URL into $CODEBASE_LOCATION"
  git clone "$GIT_REPO_URL" "$CODEBASE_LOCATION" || {
    echo "[ERROR] Failed to clone Git repo"
    exit 1
  }
fi

###############################################
### FIX: ENSURE FULL GIT HISTORY FOR FULL SCAN
###############################################
if [[ -d "$CODEBASE_LOCATION/.git" ]]; then
  cd "$CODEBASE_LOCATION"

  if git rev-parse --is-shallow-repository 2>/dev/null | grep -q "true"; then
    echo "[INFO] Repository is shallow. Fetching full history..."
    git fetch --unshallow || git fetch --all
  else
    echo "[INFO] Repository already has full history."
  fi

  cd - >/dev/null
fi

TASK_STATUS=0
MAX_COMMITS=${MAX_COMMITS:-full}  # default FULL scan
environment="${PROJECT_ENV_NAME:-$(getProjectEnv)}"
service="${COMPONENT_NAME:-$(getServiceName)}"
REPO_CLONE_DEPTH=$(getRepoCloneDepth)

###############################################
### NEW FUNCTION: DETERMINE SCAN MODE
###############################################
function computeLogOpts() {

  cd "${CODEBASE_LOCATION}" || exit 1

  TOTAL_COMMITS=$(git rev-list --count HEAD)

  # Full scan modes
  if [[ "$MAX_COMMITS" == "full" || "$MAX_COMMITS" == "0" ]]; then
    echo ""
    return
  fi

  # Numerical mode
  if [[ "$MAX_COMMITS" =~ ^[0-9]+$ ]]; then
    NUM="$MAX_COMMITS"

    # Adjust if repo depth is too small
    if [[ "$REPO_CLONE_DEPTH" -lt "$NUM" ]]; then
      NUM="$REPO_CLONE_DEPTH"
      logWarningMessage "MAX_COMMITS > clone depth. Adjusting to $NUM commits."
    fi

    # find commit range
    HEAD_HASH=$(git rev-parse HEAD)
    RANGE_START=$(git rev-parse HEAD~$NUM 2>/dev/null)

    if [[ -z "$RANGE_START" ]]; then
      logWarningMessage "Not enough commit history. Switching to full scan."
      echo ""
      return
    fi

    echo "$RANGE_START..$HEAD_HASH"
    return
  fi

  # invalid value passed
  logWarningMessage "Invalid MAX_COMMITS value: $MAX_COMMITS. Running FULL scan."
  echo ""
}

###############################################
### MAIN SCAN FUNCTION
###############################################
function scanCodeForCreds() {

  cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "${CODEBASE_LOCATION}: Directory missing"
    exit 1
  }

  mkdir -p reports

  LOG_OPTS=$(computeLogOpts)

  if [[ -z "$LOG_OPTS" ]]; then
    logInfoMessage "Performing FULL REPOSITORY SCAN"
    GITLEAKS_CMD="gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG -v --redact=90 --source ."
  else
    logInfoMessage "Scanning commit range: $LOG_OPTS"
    GITLEAKS_CMD="gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG -v --redact=90 --source . --log-opts=\"$LOG_OPTS\""
  fi

  logInfoMessage "Executing: $GITLEAKS_CMD"
  eval "$GITLEAKS_CMD"
  TASK_STATUS=$?

  # --------------------------
  # Create CSV + summary logic
  # --------------------------
  jq -r 'group_by(.RuleID) | map({RuleID: .[0].RuleID, Count: length}) | 
         (map(.RuleID) | @csv), 
         (map(.Count) | @csv)' reports/$OUTPUT_ARG \
         | sed 's/"//g' > reports/cred_scanner.csv

  if [[ ! -s reports/cred_scanner.csv ]]; then
    echo -e "no-leaks\n0" > reports/cred_scanner.csv
  fi

  logInfoMessage "Displaying Original Report"
  python3 /opt/buildpiper/shell-functions/print_table.py reports/cred_scanner.csv

  sum=$(tail -n +2 reports/cred_scanner.csv | tr ',' '\n' | awk '{sum+=$1} END {print sum}')

  echo -e "total_leaks\n$sum" > reports/cred_scanner_sum.csv

  logInfoMessage "Displaying Summary Report"
  python3 /opt/buildpiper/shell-functions/print_table.py reports/cred_scanner_sum.csv

  # send MI if enabled
  if [[ -n "${MI_SERVER_ADDRESS}" ]]; then
    export base64EncodedResponse=$(encodeFileContent reports/cred_scanner_sum.csv)
    export application=$APPLICATION_NAME
    export environment=$environment
    export service=$service
    export organization=$ORGANIZATION
    export source_key=$SOURCE_KEY
    export report_file_path=$REPORT_FILE_PATH

    generateMIDataJson /opt/buildpiper/data/mi.template gitleaks.mi
    sendMIData gitleaks.mi "${MI_SERVER_ADDRESS}"
  fi

  cp -rf reports/* "/bp/execution_dir/${GLOBAL_TASK_ID}/"
}

###############################################
### CALL MAIN LOGIC
###############################################
logInfoMessage "Scanning Git repository at [$CODEBASE_LOCATION]"
sleep $SLEEP_DURATION

if [[ -d "${CODEBASE_LOCATION}" ]]; then
  scanCodeForCreds
else
  logErrorMessage "Repo path missing. Scan failed!"
  TASK_STATUS=1
fi

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}

