FROM zricethezav/gitleaks:v8.18.1
USER root
RUN apk add --no-cache --upgrade bash \
    && apk add jq \
    && apk add gettext libintl curl
COPY build.sh .
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
ADD BP-BASE-SHELL-STEPS/data /opt/buildpiper/data
RUN chmod +x build.sh

ENV APPLICATION_NAME ""
ENV ORGANIZATION ""
ENV SOURCE_KEY ""
ENV REPORT_FILE_PATH ""

ENV MI_SERVER_ADDRESS ""

ENV ACTIVITY_SUB_TASK_CODE BP-GIT-LEAKS-TASK
ENV FORMAT_ARG json
ENV OUTPUT_ARG gitleaks.json
ENV SLEEP_DURATION 5s
ENTRYPOINT [ "./build.sh" ]
