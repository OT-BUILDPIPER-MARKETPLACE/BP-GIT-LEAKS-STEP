#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/mi-functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh
source /opt/buildpiper/shell-functions/getDataFile.sh

TASK_STATUS=0

function scanCodeForCreds() {

  logInfoMessage "Below command will be executed"
  logInfoMessage "gitleaks detect ${CODEBASE_LOCATION} --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG"
  logInfoMessage "Validating Git repository for vulnerabilities..."

  cd ${CODEBASE_LOCATION}

  if [ -d "reports" ]; then
      true
  else
      mkdir reports 
  fi

  gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG -v
  
  TASK_STATUS=$?
  jq -r 'group_by(.RuleID) | map({RuleID: .[0].RuleID, Count: length}) | (map(.RuleID) | @csv), (map(.Count) | @csv)' reports/$OUTPUT_ARG | sed 's/"//g' > reports/cred_scanner.csv

  # add data to reports/cred_scanner.csv if no leaks in code found
  if [ ! -s reports/cred_scanner.csv ] || [ "$(cat reports/cred_scanner.csv | tr -d '[:space:]')" = "" ]; then
      echo "no-leaks" > reports/cred_scanner.csv
      echo "0" >> reports/cred_scanner.csv
  fi

  # Display the original CSV 
  #   NOTE: Using python3 print_table.py custom script to print the tabular data.

  logInfoMessage "Displaying Original Report: reports/cred_scanner.csv"
  echo "================================================================================"
  python3 /usr/local/bin/print_table.py reports/cred_scanner.csv
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
  python3 /usr/local/bin/print_table.py reports/cred_scanner_sum.csv
  echo "================================================================================"

  export base64EncodedResponse=`encodeFileContent reports/cred_scanner_sum.csv`
  export application=$APPLICATION_NAME
  export environment=`getProjectEnv`
  export service=`getServiceName`
  export organization=$ORGANIZATION
  export source_key=$SOURCE_KEY
  export report_file_path=$REPORT_FILE_PATH

  generateMIDataJson /opt/buildpiper/data/mi.template gitleaks.mi
  cat gitleaks.mi
  sendMIData gitleaks.mi ${MI_SERVER_ADDRESS}
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