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

  cat reports/cred_scanner.csv

  # cred_scanner="reports/cred_scanner.csv"

  # Read the first line as the filename
  cred_scanner=$(head -n 1 "reports/cred_scanner.csv")

  # Read the second line and calculate the sum
  sum=$(tail -n +2 "reports/cred_scanner.csv" | tr ',' '\n' | awk '{sum+=$1} END {print sum}')

  # Create a new CSV file with the sum
  echo "$cred_scanner" > "reports/${cred_scanner}_sum.csv"
  echo "$sum" >> "reports/${cred_scanner}_sum.csv"

  logInfoMessage "Sum has been saved to reports/${cred_scanner}_sum.csv"
  # csv=$(print_csv "reports/${cred_scanner}_sum.csv")
  cat reports/${cred_scanner}_sum.csv

  export base64EncodedResponse=`encodeFileContent reports/${cred_scanner}_sum.csv`
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