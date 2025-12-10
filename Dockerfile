FROM zricethezav/gitleaks:latest


# Create user and group (Alpine syntax)
RUN addgroup -g 65522 buildpiper && \
    adduser -u 65522 -G buildpiper -D -h /home/buildpiper buildpiper && \
    chown -R buildpiper:buildpiper /home/buildpiper

RUN mkdir -p \
    /src/reports \
    /bp/data \
    /bp/execution_dir \
    /opt/buildpiper/shell-functions \
    /opt/buildpiper/data \
    /bp/workspace \
    /usr/local/bin \
    /var/lib/apt/lists \
    /etc/timezone \
    /opt/python_versions \
    /opt/jdk \
    /opt/maven \
    /app/venv && \
    chown -R buildpiper:buildpiper /src /bp /opt /usr /tmp /app

# Install dependencies
RUN apk --no-cache add \
    bash jq gettext libintl curl python3 py3-pip py3-virtualenv

# ADDITION #1: Install git + CA certificates + timezone support
RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata && \
    update-ca-certificates

# ADDITION #2: Use bash as default shell
SHELL ["/bin/bash", "-c"]

# Create a virtual environment and install Python packages inside it
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir tabulate

# Set environment variables to use the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Copy files efficiently with correct permissions
COPY --chown=buildpiper:buildpiper build.sh .
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/data /opt/buildpiper/data
RUN chmod +x build.sh

# ADDITION #3: Create log dir for BP scripts
RUN mkdir -p /app/logs && \
    chown -R buildpiper:buildpiper /app/logs

# Environment variables
ENV APPLICATION_NAME="" \
    ORGANIZATION="" \
    SOURCE_KEY="gitleak" \
    FORMAT_ARG="json" \
    OUTPUT_ARG="gitleaks.json" \
    REPORT_FILE_PATH="null" \
    MI_SERVER_ADDRESS="" \
    ACTIVITY_SUB_TASK_CODE="BP-GIT-LEAKS-TASK" \
    VALIDATION_ACTION_FAILURE="WARNING" \
    SLEEP_DURATION="5s"

USER buildpiper

ENTRYPOINT [ "./build.sh" ]

