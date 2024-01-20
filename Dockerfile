FROM zricethezav/gitleaks:v8.18.1
USER root
RUN apk add --no-cache --upgrade bash \
    && apk add jq \
    && apk add gettext libintl curl
COPY build.sh .
COPY mi.template .
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
RUN chmod +x build.sh
ENV ACTIVITY_SUB_TASK_CODE BP-GIT-LEAKS-TASK
ENV FORMAT_ARG json
ENV OUTPUT_ARG gitleaks.json
ENV SLEEP_DURATION 5s
USER gitleaks
ENTRYPOINT [ "./build.sh" ]
