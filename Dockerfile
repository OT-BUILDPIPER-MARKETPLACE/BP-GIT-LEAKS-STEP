FROM zricethezav/gitleaks
USER root
RUN apk add --no-cache --upgrade bash
RUN apk add jq
COPY build.sh .
COPY BP-BASE-SHELL-STEPS .
RUN chmod +x build.sh
ENV ACTIVITY_SUB_TASK_CODE BP-GIT-LEAKS-TASK
ENV FORMAT_ARG json 
ENV OUTPUT_ARG gitleaks.json 
ENV SLEEP_DURATION 5s
ENTRYPOINT [ "./build.sh" ]