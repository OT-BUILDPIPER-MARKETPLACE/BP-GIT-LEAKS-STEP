#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/mi-functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source /opt/buildpiper/shell-functions/getDataFile.sh

git config --global --add safe.directory "$(pwd)"

###############################################
### EVENTS TRACKING
###############################################
EVENTS='{}'

add_event() {
  local key="${1:-}"
  local status="${2:-}"
  local reason="${3:-}"
  local message="${4:-}"

  # Validate input
  if [ -z "$key" ] || [ -z "$status" ]; then
    echo "Error: add_event requires at least 'key' and 'status' parameters" >&2
    return 1
  fi

  # Normalize key: convert to lowercase and replace separators with spaces
  key="$(echo "$key" | tr '_' ' ' | tr '-' ' ' | tr '[:upper:]' '[:lower:]')"

  # Use jq to safely add event to EVENTS JSON
  EVENTS=$(jq \
    --arg k "$key" \
    --arg status "$status" \
    --arg reason "$reason" \
    --arg message "$message" \
    '. + {
      ($k): {
        status: $status,
        reason: $reason,
        message: $message
      }
    }' <<< "$EVENTS") || {
    echo "Error: Failed to add event to EVENTS JSON" >&2
    return 1
  }

  return 0
}

###############################################
### OUTPUT FILE
###############################################
GITLEAKS_OUTPUT_FILE="${GITLEAKS_OUTPUT_FILE:-${ACTIVITY_SUB_TASK_CODE}_output.json}"

###############################################
### SET DEFAULT FORMAT AND OUTPUT IF NOT SET
###############################################
FORMAT_ARG="${FORMAT_ARG:-csv}"
OUTPUT_ARG="${OUTPUT_ARG:-cred_scanner.csv}"

###############################################
### INPUT VALIDATION
###############################################
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"

if [[ -z "$WORKSPACE" || -z "$CODEBASE_DIR" ]]; then
  logErrorMessage "Missing required variables: WORKSPACE or CODEBASE_DIR"
  add_event "input validation" "Failed" "Missing required variables" "WORKSPACE or CODEBASE_DIR is not set"
  saveTaskStatus 1 ${ACTIVITY_SUB_TASK_CODE}
  exit 1
fi
add_event "input validation" "Successful" "Required variables present" "WORKSPACE and CODEBASE_DIR are set"

###############################################
### CLONE REPO
###############################################
if [[ ! -d "$CODEBASE_LOCATION" && -n "$GIT_REPO_URL" ]]; then
  logInfoMessage "Cloning $GIT_REPO_URL into $CODEBASE_LOCATION"
  git clone "$GIT_REPO_URL" "$CODEBASE_LOCATION" || {
    logErrorMessage "Failed to clone Git repo"
    add_event "clone repository" "Failed" "Git clone error" "Failed to clone $GIT_REPO_URL into $CODEBASE_LOCATION"
    saveTaskStatus 1 ${ACTIVITY_SUB_TASK_CODE}
    exit 1
  }
  add_event "clone repository" "Successful" "Repo cloned" "Cloned $GIT_REPO_URL into $CODEBASE_LOCATION"
else
  add_event "clone repository" "Successful" "Directory already exists" "Using existing codebase at $CODEBASE_LOCATION"
fi

###############################################
### ENSURE FULL GIT HISTORY
###############################################
if [[ -d "$CODEBASE_LOCATION/.git" ]]; then
  cd "$CODEBASE_LOCATION"

  if git rev-parse --is-shallow-repository 2>/dev/null | grep -q "true"; then
    logInfoMessage "Repository is shallow. Fetching full history..."
    git fetch --unshallow --quiet 2>/dev/null || git fetch --all --quiet 2>/dev/null
    add_event "fetch git history" "Successful" "Shallow repo unshallowed" "Full git history fetched for $CODEBASE_LOCATION"
  else
    logInfoMessage "Repository already has full history."
    add_event "fetch git history" "Successful" "Full history already present" "No unshallow needed for $CODEBASE_LOCATION"
  fi

  cd - >/dev/null
fi

TASK_STATUS=0
MAX_COMMITS=${MAX_COMMITS:-full}  # default FULL scan
environment="${PROJECT_ENV_NAME:-$(getProjectEnv)}"
service="${COMPONENT_NAME:-$(getServiceName)}"
REPO_CLONE_DEPTH=$(getRepoCloneDepth)

###############################################
### THRESHOLD CONFIGURATION
### LEAK_THRESHOLD: max number of leaks allowed
###   - Default: 0 (zero tolerance)
###   - Set to -1 to disable threshold checks entirely
###############################################
LEAK_THRESHOLD="${LEAK_THRESHOLD:-0}"

###############################################
### FUNCTION: DETERMINE SCAN MODE
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
### THRESHOLD CHECK FUNCTION
###############################################
function checkThreshold() {
  local total_leaks=$1

  # Threshold disabled
  if [[ "$LEAK_THRESHOLD" == "-1" ]]; then
    logInfoMessage "Threshold check is DISABLED (LEAK_THRESHOLD=-1). Skipping."
    add_event "threshold check" "Successful" "Threshold disabled" "LEAK_THRESHOLD=-1, threshold enforcement is off"
    return 0
  fi

  # Validate threshold is a non-negative integer
  if ! [[ "$LEAK_THRESHOLD" =~ ^[0-9]+$ ]]; then
    logWarningMessage "Invalid LEAK_THRESHOLD value: '$LEAK_THRESHOLD'. Must be a non-negative integer or -1 to disable. Defaulting to 0."
    add_event "threshold validation" "Successful" "Invalid threshold value" "LEAK_THRESHOLD='$LEAK_THRESHOLD' is invalid, defaulted to 0"
    LEAK_THRESHOLD=0
  fi

  logInfoMessage "-------------------------------------------"
  logInfoMessage "THRESHOLD CHECK"
  logInfoMessage "  Allowed  (LEAK_THRESHOLD) : $LEAK_THRESHOLD"
  logInfoMessage "  Detected (total leaks)    : $total_leaks"
  logInfoMessage "-------------------------------------------"

  if [[ "$total_leaks" -gt "$LEAK_THRESHOLD" ]]; then
    logErrorMessage "THRESHOLD BREACHED: Found $total_leaks leak(s), but limit is $LEAK_THRESHOLD. Failing the task."
    add_event "threshold check" "Failed" "Threshold breached" "Found $total_leaks leak(s), allowed limit is $LEAK_THRESHOLD"
    return 1
  else
    logInfoMessage "THRESHOLD PASSED: Found $total_leaks leak(s), within the allowed limit of $LEAK_THRESHOLD."
    add_event "threshold check" "Successful" "Within allowed limit" "Found $total_leaks leak(s), allowed limit is $LEAK_THRESHOLD"
    return 0
  fi
}

###############################################
### MAIN SCAN FUNCTION
###############################################
function scanCodeForCreds() {

  cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "${CODEBASE_LOCATION}: Directory missing"
    add_event "scan setup" "Failed" "Codebase directory missing" "$CODEBASE_LOCATION does not exist"
    exit 1
  }

  mkdir -p reports

  # ----------------------------------------
  # Determine scan range
  # ----------------------------------------
  LOG_OPTS=$(computeLogOpts)

  if [[ -z "$LOG_OPTS" ]]; then
    logInfoMessage "Performing FULL REPOSITORY SCAN"
    SCAN_MODE="full"
    add_event "compute scan mode" "Successful" "Full repository scan" "Scanning entire git history (MAX_COMMITS=$MAX_COMMITS)"
    GITLEAKS_CMD="gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path $OUTPUT_ARG -v --redact=90 --source ."
  else
    logInfoMessage "Scanning commit range: $LOG_OPTS"
    SCAN_MODE="range"
    add_event "compute scan mode" "Successful" "Commit range scan" "Scanning commit range: $LOG_OPTS"
    GITLEAKS_CMD="gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path $OUTPUT_ARG -v --redact=90 --source . --log-opts=\"$LOG_OPTS\""
  fi

  # ----------------------------------------
  # Run gitleaks
  # ----------------------------------------
  logInfoMessage "Executing: $GITLEAKS_CMD"
  if [[ "$DEBUG" == "true" ]]; then
    eval "$GITLEAKS_CMD"
  else
    eval "$GITLEAKS_CMD" > /dev/null 2>&1
  fi
  GITLEAKS_EXIT_CODE=$?


  # ----------------------------------------
  # DEBUG: Check if file was created
  # ----------------------------------------
  if [[ "$DEBUG" == "true" ]]; then
    logInfoMessage "DEBUG: Checking for output file: $OUTPUT_ARG"
    if [[ -f "$OUTPUT_ARG" ]]; then
      logInfoMessage "DEBUG: File EXISTS. Size: $(ls -lh $OUTPUT_ARG | awk '{print $5}')"
      logInfoMessage "DEBUG: First 5 lines:"
      head -n 5 "$OUTPUT_ARG"
    else
      logErrorMessage "DEBUG: File DOES NOT EXIST!"
      logInfoMessage "DEBUG: Current directory: $(pwd)"
      logInfoMessage "DEBUG: Files in current directory:"
      ls -la
    fi
  fi  

  if [[ "$GITLEAKS_EXIT_CODE" -gt 1 ]]; then
    add_event "gitleaks scan" "Failed" "Gitleaks execution error" "gitleaks exited with unexpected code $GITLEAKS_EXIT_CODE"
  elif [[ "$GITLEAKS_EXIT_CODE" -eq 1 ]]; then
    add_event "gitleaks scan" "Successful" "Leaks detected" "gitleaks completed — secrets found in repository"
  else
    add_event "gitleaks scan" "Successful" "No leaks detected" "gitleaks completed — repository is clean"
  fi

  # ----------------------------------------
  # Process output based on format (CSV or JSON)
  # ----------------------------------------
  if [[ "$FORMAT_ARG" == "csv" ]]; then
    # CSV format processing
    if [[ -s "$OUTPUT_ARG" ]]; then
      # Copy the CSV directly
      cp "$OUTPUT_ARG" cred_scanner.csv
      
      # Count total leaks (excluding header)
      sum=$(tail -n +2 cred_scanner.csv | wc -l)
      sum="${sum:-0}"
      
      logInfoMessage "DEBUG: Counted $sum leaks from CSV file"
      add_event "generate csv report" "Successful" "CSV report generated" "Found $sum secret leak(s) in repository"
    else
      # No leaks found
      sum=0
      logWarningMessage "DEBUG: CSV file is empty or does not exist, creating fallback"
      echo "RuleID,Description,StartLine,EndLine,StartColumn,EndColumn,Match,Secret,File,SymlinkFile,Commit,Entropy,Author,Email,Date,Message,Tags,RuleID" > cred_scanner.csv
      echo "no-leaks,No secrets detected,0,0,0,0,N/A,N/A,N/A,N/A,N/A,0,N/A,N/A,N/A,N/A,N/A,N/A" >> cred_scanner.csv
      add_event "generate csv report" "Successful" "No leaks found" "cred_scanner.csv created with zero leaks"
    fi
  else
    # JSON format processing
    if [[ -s "$OUTPUT_ARG" ]] && jq -e '.[] | select(. != null)' "$OUTPUT_ARG" >/dev/null 2>&1; then
      
      # Group by RuleID and create summary CSV
      jq -r '
        group_by(.RuleID) | 
        map({rule: (.[0].RuleID // "unknown"), count: length, file: (.[0].File // "N/A")}) |
        ["Rule ID", "Count", "File"],
        (.[] | [.rule, .count, .file]) |
        @csv
      ' "$OUTPUT_ARG" | sed 's/"//g' > cred_scanner.csv
      
      # Calculate total
      sum=$(jq '[.[] | select(. != null)] | length' "$OUTPUT_ARG" 2>/dev/null || echo 0)
      sum="${sum:-0}"
      
      logInfoMessage "DEBUG: Counted $sum leaks from JSON file"
      add_event "generate csv report" "Successful" "CSV report generated" "cred_scanner.csv populated with leak breakdown by RuleID"
      
    else
          # No leaks found
          sum=0
          logWarningMessage "DEBUG: JSON file is empty or invalid, creating fallback"
          echo "Rule ID,Count,File" > cred_scanner.csv
          echo "no-leaks,0,N/A" >> cred_scanner.csv
          add_event "generate csv report" "Successful" "No leaks found" "cred_scanner.csv created with zero leaks"
        fi
  fi

  # Create total summary - 2 columns, no header for MI server
  echo -e "total_leaks\n$sum" > cred_scanner_sum.csv
  cat cred_scanner_sum.csv
  add_event "generate summary report" "Successful" "Summary computed" "Total leaks counted: $sum"

  # Display leak report
  logInfoMessage "Displaying Leak Report by Rule"
  python3 /opt/buildpiper/shell-functions/print_table.py cred_scanner.csv

  # Display summary report (separate file with header, only for display)
  logInfoMessage "Displaying Summary Report"
  echo "Metric,Value" > cred_scanner_sum_display.csv
  echo "Total Leaks,$sum" >> cred_scanner_sum_display.csv
  python3 /opt/buildpiper/shell-functions/print_table.py cred_scanner_sum_display.csv

  # ----------------------------------------
  # Threshold evaluation
  # ----------------------------------------
  checkThreshold "$sum"
  THRESHOLD_STATUS=$?

  # ----------------------------------------
  # Determine final task status
  # ----------------------------------------
  if [[ "$GITLEAKS_EXIT_CODE" -gt 1 ]]; then
    logErrorMessage "Gitleaks encountered an unexpected error (exit code: $GITLEAKS_EXIT_CODE)."
    TASK_STATUS=$GITLEAKS_EXIT_CODE
    FINAL_STATUS="failed"
    FINAL_REASON="Gitleaks execution error"
    FINAL_MESSAGE="gitleaks exited with unexpected code $GITLEAKS_EXIT_CODE"
  elif [[ "$THRESHOLD_STATUS" -ne 0 ]]; then
    TASK_STATUS=1
    FINAL_STATUS="failed"
    FINAL_REASON="Threshold breached"
    FINAL_MESSAGE="Found $sum leak(s) which exceeds the allowed limit of $LEAK_THRESHOLD"
  else
    TASK_STATUS=0
    FINAL_STATUS="Successful"
    FINAL_REASON="Scan completed"
    FINAL_MESSAGE="Credential scan passed. Total leaks: $sum, Threshold: $LEAK_THRESHOLD"
  fi

  # ----------------------------------------
  # Build error_events list from EVENTS
  # ----------------------------------------
  ERROR_EVENTS=$(echo "$EVENTS" | jq '[to_entries[] | select(.value.status == "Failed") | .key]')


  # ----------------------------------------
  # Send MI if enabled
  # ----------------------------------------

  if [[ -n "${MI_SERVER_ADDRESS}" ]]; then
      logInfoMessage "MI_SERVER_ADDRESS: ${MI_SERVER_ADDRESS}"
      export base64EncodedResponse=$(encodeFileContent cred_scanner_sum.csv)
      export application=$APPLICATION_NAME
      export environment=$environment
      export service=$service
      export organization=$ORGANIZATION
      export source_key=$SOURCE_KEY
      if [[ -z "$REPORT_FILE_PATH" || "$REPORT_FILE_PATH" == "null" ]]; then
        export report_file_path=""
      else
        export report_file_path="$REPORT_FILE_PATH"
      fi
      generateMIDataJson /opt/buildpiper/data/mi.template gitleaks.mi
      response=$(sendMIData gitleaks.mi "${MI_SERVER_ADDRESS}")
      status=$?

      if [ $status -eq 0 ]; then
        clean_response=$(echo "$response" | grep -o '{.*}')
        logInfoMessage "Send MI Data API Response: SUCCESS $clean_response"
        add_event "send mi data" "Successful" "Send MI Data API Response: SUCCESS" "$response"
      else
        clean_response=$(echo "$response" | grep -o '{.*}')
        logErrorMessage "Send MI Data API Response: FAILED $clean_response"
        add_event "send mi data" "Failed" "Send MI Data API Response: FAILED" "$response"
      fi
    fi
    
  # ----------------------------------------
  # Map FINAL_STATUS to boolean to match
  # cloning_repository_output.json format
  # ----------------------------------------
  if [[ "$FINAL_STATUS" == "Successful" ]]; then
    STATUS_BOOL="true"
  else
    STATUS_BOOL="false"
  fi

  # ----------------------------------------
  # Create structured output JSON
  # ----------------------------------------
  mkdir -p "/bp/execution_dir/${GLOBAL_TASK_ID}"

  if ! jq -n \
    --argjson events "$EVENTS" \
    --argjson error_events "$ERROR_EVENTS" \
    --argjson status_bool "$STATUS_BOOL" \
    --arg final_reason "$FINAL_REASON" \
    --arg final_message "$FINAL_MESSAGE" \
    --arg scan_mode "$SCAN_MODE" \
    --arg log_opts "$LOG_OPTS" \
    --arg max_commits "$MAX_COMMITS" \
    --arg total_leaks "$sum" \
    --arg leak_threshold "$LEAK_THRESHOLD" \
    --arg codebase_location "$CODEBASE_LOCATION" \
    --arg environment "$environment" \
    --arg service "$service" \
    '{
      build: {
        status: $status_bool,
        reason: $final_reason,
        message: $final_message,
        events: $events,
        current_error: (if $status_bool == "false" then $final_reason else "" end),
        error_events: $error_events
      },
      output_vars: {
        gitleaks_scan: {
          status: $status_bool,
          reason: $final_reason,
          message: $final_message,
          scan: {
            mode: $scan_mode,
            log_opts: $log_opts,
            max_commits: $max_commits,
            codebase_location: $codebase_location
          },
          results: {
            total_leaks: ($total_leaks | tonumber),
            leak_threshold: ($leak_threshold | tonumber),
            threshold_enforced: ($leak_threshold != "-1")
          },
          context: {
            environment: $environment,
            service: $service
          },
          current_error: (if $status_bool == "false" then $final_reason else "" end),
          error_events: $error_events
        }
      }
    }' > "/bp/execution_dir/${GLOBAL_TASK_ID}/$GITLEAKS_OUTPUT_FILE"; then
    logErrorMessage "Failed to create gitleaks output file"
    add_event "create output" "Failed" "File creation failed" "Could not write /bp/execution_dir/${GLOBAL_TASK_ID}/$GITLEAKS_OUTPUT_FILE"
  else
    logInfoMessage "Output JSON written to /bp/execution_dir/${GLOBAL_TASK_ID}/$GITLEAKS_OUTPUT_FILE"
    add_event "create output" "Successful" "Output file created" "Structured output written to /bp/execution_dir/${GLOBAL_TASK_ID}/$GITLEAKS_OUTPUT_FILE"
  fi 

  cp "$OUTPUT_ARG" "/bp/execution_dir/${GLOBAL_TASK_ID}/"

  # ----------------------------------------
  # Signal pass/fail to BuildPiper pipeline
  # ----------------------------------------
  if [[ "$TASK_STATUS" -eq 0 ]]; then
    logInfoMessage "Congratulations! Credential scan passed."
    generateOutput ${ACTIVITY_SUB_TASK_CODE} true "$FINAL_MESSAGE"

  elif [[ "${VALIDATION_FAILURE_ACTION:-FAILURE}" == "FAILURE" ]]; then
    logErrorMessage "Credential scan FAILED. Stopping pipeline."
    generateOutput ${ACTIVITY_SUB_TASK_CODE} false "$FINAL_MESSAGE"
    exit 1

  else
    logWarningMessage "Credential scan failed, but the step is configured as NON-BLOCKING (warning mode).

  If you want the pipeline to FAIL on leaks:
  - Go to job template settings
  - Set VALIDATION_FAILURE_ACTION = FAILURE

  Current setting allows pipeline to continue."

    add_event "validation mode" "Successful" "Non-blocking validation" "Scan failed but pipeline continued because VALIDATION_FAILURE_ACTION is not FAILURE"

    generateOutput ${ACTIVITY_SUB_TASK_CODE} false "$FINAL_MESSAGE"  
  fi
  }

###############################################
### CALL MAIN LOGIC
###############################################
logInfoMessage "Scanning Git repository at [$CODEBASE_LOCATION]"
logInfoMessage "Leak threshold set to: ${LEAK_THRESHOLD} (use -1 to disable)"
sleep $SLEEP_DURATION

if [[ -d "${CODEBASE_LOCATION}" ]]; then
  scanCodeForCreds
else
  logErrorMessage "Repo path missing. Scan failed!"
  add_event "repo path check" "Failed" "Directory not found" "Codebase location $CODEBASE_LOCATION does not exist"
  TASK_STATUS=1
  generateOutput ${ACTIVITY_SUB_TASK_CODE} false "Codebase location $CODEBASE_LOCATION does not exist"
  exit 1
fi

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
