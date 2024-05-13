#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/mi-functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

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

  export base64EncodedResponse=`encodeFileContent reports/cred_scanner.csv`
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