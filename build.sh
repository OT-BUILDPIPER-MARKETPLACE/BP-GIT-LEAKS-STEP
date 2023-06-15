#!/bin/bash

source  functions.sh
source  log-functions.sh
source  str-functions.sh
source  file-functions.sh
source  aws-functions.sh

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

cd $code

if [ -d "reports" ]; then
    true
else
    mkdir reports 
fi

gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG -v

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
