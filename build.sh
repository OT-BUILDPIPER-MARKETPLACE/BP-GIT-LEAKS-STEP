#!/bin/bash

source functions.sh
source mi_functions.sh
source log-functions.sh
source str-functions.sh
source file-functions.sh
source aws-functions.sh

# for locally testing
#mkdir /$1
#WORKSPACE=$1
#git clone $2 /$1/code_to_scan
#CODEBASE_DIR=code_to_scan

code="$WORKSPACE/$CODEBASE_DIR"

logInfoMessage "I'll scan Git repository for vulnerabilities"
sleep $SLEEP_DURATION
logInfoMessage "Executing command"
logInfoMessage "gitleaks detect $code --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG"
logInfoMessage "Validating Git repository for vulnerabilities..."

if [ -d $code ];then
   true
else
    logErrorMessage "$WORKSPACE/$CODEBASE_DIR: No such file or directory exist"
    logErrorMessage "Please check Git repository vulnerabilities scan failed!!!"
    generateOutput $ACTIVITY_SUB_TASK_CODE false "Please check Git repository vulnerabilities scan failed!!!"
    exit 1
fi

cp mi.template $code
cd $code

if [ -d "reports" ]; then
    true
else
    mkdir reports 
fi

gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG -v

jq -r 'group_by(.RuleID) | map({RuleID: .[0].RuleID, Count: length}) | (map(.RuleID) | @csv), (map(.Count) | @csv)' reports/$OUTPUT_ARG | sed 's/"//g' > reports/cred_scanner.csv

export base64EncodedResponse=`encodeFileContent reports/cred_scanner.csv`
export application=ot-demo-ms
export environment=dev-main
export service=salary
export organization=bp
export source_key=gitleaks
export report_file_path=null

generateReportJson mi.template gitleaks.mi

sendMIData gitleaks.mi http://192.168.1.202:9001
if [ $? -ne 0 ]; then
  if [ "$VALIDATION_FAILURE_ACTION" == "FAILURE" ]
  then
    logErrorMessage "$CODEBASE_DIR: Vulnerabilities found in the Git repository."
    logErrorMessage "Please check Git repository vulnerabilities scan failed!!!"
    generateOutput $ACTIVITY_SUB_TASK_CODE false "Please check Git repository vulnerabilities scan failed!!!"
    exit 1
  else
    logErrorMessage "$CODEBASE_DIR: Vulnerabilities found in the Git repository."
    logWarningMessage "Please check Git repository vulnerabilities scan failed!!!"
    generateOutput $ACTIVITY_SUB_TASK_CODE true "Please check Git repository vulnerabilities scan failed!!!"
  fi
else
  logInfoMessage "$CODEBASE_DIR: Git repository is secure."
  logInfoMessage "Congratulations Git repository vulnerabilities scan succeeded!!!"
fi
