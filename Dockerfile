FROM zricethezav/gitleaks:v8.18.1
USER root

# Install dependencies in a single RUN layer to reduce image size
RUN apk add --no-cache --upgrade \
    bash jq gettext libintl curl nodejs npm && \
    npm install -g tty-table && \
    rm -rf /var/cache/apk/*

COPY build.sh .
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
ADD BP-BASE-SHELL-STEPS/data /opt/buildpiper/data
RUN chmod +x build.sh

ENV APPLICATION_NAME ""
ENV ORGANIZATION ""
ENV SOURCE_KEY gitleak
ENV FORMAT_ARG json
ENV OUTPUT_ARG gitleaks.json
ENV REPORT_FILE_PATH null

ENV MI_SERVER_ADDRESS ""

ENV ACTIVITY_SUB_TASK_CODE BP-GIT-LEAKS-TASK
ENV FORMAT_ARG json
ENV OUTPUT_ARG gitleaks.json
ENV SLEEP_DURATION 5s
ENTRYPOINT [ "./build.sh" ]
