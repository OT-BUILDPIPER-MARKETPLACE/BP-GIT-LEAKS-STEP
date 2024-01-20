function encodeFileContent() {
    local FILE_PATH=$1
    base64 $FILE_PATH
}

function generateReportJson() {
    TEMPLATE_FILE=$1
    RESULTANT_FILE=$2

    echo "base64EncodedResponse: [${base64EncodedResponse}]"
    envsubst < ${TEMPLATE_FILE} > ${RESULTANT_FILE}
}

function sendMIData() {
    DATA_FILE=$1
    MI_SERVER="$2"

    curl -d "@${DATA_FILE}" -X POST  -H "Content-Type: application/json"  ${MI_SERVER}/api/v1/default/maturity_metrices/

}