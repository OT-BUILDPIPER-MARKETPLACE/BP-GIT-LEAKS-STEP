#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/mi-functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source /opt/buildpiper/shell-functions/getDataFile.sh

TASK_STATUS=0
MAX_COMMITS=${MAX_COMMITS:-0}  # Default to scanning all commits if not set
environment="${PROJECT_ENV_NAME:-$(getProjectEnv)}"
service="${COMPONENT_NAME:-$(getServiceName)}"
REPO_CLONE_DEPTH=`getRepoCloneDepth`

function getCommitRange() {
  TOTAL_COMMITS=$(git rev-list --count HEAD)
  
  if [[ "$TOTAL_COMMITS" -lt "$MAX_COMMITS" || "$MAX_COMMITS" -eq 0 ]]; then
    SCAN_COMMITS="$TOTAL_COMMITS"
  else
    SCAN_COMMITS="$MAX_COMMITS"
  fi

  LATEST_COMMIT=$(git rev-parse HEAD)
  PREVIOUS_COMMIT=$(git rev-list --max-count=$SCAN_COMMITS HEAD | tail -n 1)

  echo "$PREVIOUS_COMMIT..$LATEST_COMMIT"
}

function scanCodeForCreds() {

#   logInfoMessage "Below command will be executed"
#   logInfoMessage "gitleaks detect ${CODEBASE_LOCATION} --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG"
  logInfoMessage "Validating Git repository for vulnerabilities..."

  cd ${CODEBASE_LOCATION} || {
  logErrorMessage "${CODEBASE_LOCATION}: No such directory exists"
  exit 1
  }

  [ -d "reports" ] || mkdir reports

  COMMIT_RANGE=$(getCommitRange)
  logInfoMessage "Scanning commits in range: $COMMIT_RANGE"

  if [[ $MAX_COMMITS -gt 0 ]]; then
    if [[ -n "$REPO_CLONE_DEPTH" && "$REPO_CLONE_DEPTH" -lt "$MAX_COMMITS" ]]; then
      logWarningMessage "REPO_CLONE_DEPTH ($REPO_CLONE_DEPTH) is less than MAX_COMMITS ($MAX_COMMITS). Adjusting to scan within available history."
      MAX_COMMITS=$REPO_CLONE_DEPTH
    fi

    COMMIT_HASH=$(git rev-parse HEAD~$MAX_COMMITS 2>/dev/null)
    
    if [[ -z "$COMMIT_HASH" ]]; then
      logErrorMessage "Invalid commit range. Scanning full repository."
      COMMIT_HASH=""
    else
      logInfoMessage "Scanning the last $MAX_COMMITS commits from $COMMIT_HASH"
    fi
  fi

  GITLEAKS_CMD="gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG -v --redact=90 --source . --log-opts=\"$COMMIT_RANGE\""

  logInfoMessage "Executing: $GITLEAKS_CMD"
  eval "$GITLEAKS_CMD"
  TASK_STATUS=$?
  jq -r 'group_by(.RuleID) | map({RuleID: .[0].RuleID, Count: length}) | (map(.RuleID) | @csv), (map(.Count) | @csv)' reports/$OUTPUT_ARG | sed 's/"//g' > reports/cred_scanner.csv

  if [ ! -s reports/cred_scanner.csv ] || [ -z "$(cat reports/cred_scanner.csv | tr -d '[:space:]')" ]; then
    echo "no-leaks" > reports/cred_scanner.csv
    echo "0" >> reports/cred_scanner.csv
  fi

  # add data to reports/cred_scanner.csv if no leaks in code found
  if [ ! -s reports/cred_scanner.csv ] || [ "$(cat reports/cred_scanner.csv | tr -d '[:space:]')" = "" ]; then
      echo "no-leaks" > reports/cred_scanner.csv
      echo "0" >> reports/cred_scanner.csv
  fi

  # Display the original CSV 
  # NOTE: Using python3 print_table.py custom script to print the tabular data.
  logInfoMessage "Displaying Original Report: reports/cred_scanner.csv"
  echo "================================================================================"
  python3 /opt/buildpiper/shell-functions/print_table.py reports/cred_scanner.csv
  echo "================================================================================"

  # Read and process the CSV
  logInfoMessage "Calculating the total number of leaks from reports/cred_scanner.csv..."

  # Calculate the sum
  sum=$(tail -n +2 "reports/cred_scanner.csv" | tr ',' '\n' | awk '{sum+=$1} END {print sum}')
  
  # Create a new CSV with the sum
  echo "total_leaks" > "reports/cred_scanner_sum.csv"
  echo "$sum" >> "reports/cred_scanner_sum.csv"
  
  logInfoMessage "Total leaks calculated: $sum"
  logInfoMessage "Sum has been saved to reports/cred_scanner_sum.csv"
  
  # Display the summary CSV
  logInfoMessage "Displaying Leak Summary Report: reports/cred_scanner_sum.csv"
  echo "================================================================================"
  python3 /opt/buildpiper/shell-functions/print_table.py reports/cred_scanner_sum.csv
  echo "================================================================================"

  # Only send MI data if MI_SERVER_ADDRESS is provided
  if [[ -n "${MI_SERVER_ADDRESS}" ]]; then
    export base64EncodedResponse=$(encodeFileContent reports/cred_scanner_sum.csv)
    export application=$APPLICATION_NAME
    export environment=$environment
    export service=$service
    export organization=$ORGANIZATION
    export source_key=$SOURCE_KEY
    export report_file_path=$REPORT_FILE_PATH

    generateMIDataJson /opt/buildpiper/data/mi.template gitleaks.mi
    cat gitleaks.mi
    sendMIData gitleaks.mi "${MI_SERVER_ADDRESS}"
  else
    logInfoMessage "MI_SERVER_ADDRESS not provided. Skipping MI data send."
  fi

  logInfoMessage "Updating reports in /bp/execution_dir/${GLOBAL_TASK_ID}......."
  cp -rf reports/* /bp/execution_dir/${GLOBAL_TASK_ID}/
}

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll scan Git repository for vulnerabilities [$CODEBASE_LOCATION]"

sleep $SLEEP_DURATION

if [ -d ${CODEBASE_LOCATION} ];then
   scanCodeForCreds
else
    logErrorMessage "${CODEBASE_LOCATION}: No such file or directory exist"
    logErrorMessage "Please check Git repository vulnerabilities scan failed!!!"
    generateOutput $ACTIVITY_SUB_TASK_CODE false "Please check Git repository vulnerabilities scan failed!!!"
    TASK_STATUS=1
fi

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
