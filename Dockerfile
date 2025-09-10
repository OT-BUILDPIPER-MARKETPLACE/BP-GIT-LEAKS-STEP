FROM zricethezav/gitleaks:latest
# Set working directory
WORKDIR /home/buildpiper
# Install dependencies
RUN apk --no-cache add bash jq gettext libintl curl python3 py3-pip py3-virtualenv && \
    addgroup -g 65522 buildpiper && \
    adduser -D -h /home/buildpiper -u 65522 -G buildpiper buildpiper && \
    mkdir -p /home/buildpiper && chown -R buildpiper:buildpiper /home/buildpiper

# Create a virtual environment and install Python packages inside it
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir tabulate

# Set environment variables to use the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Copy files with correct ownership
COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/data /opt/buildpiper/data/

# Make the build script executable
RUN chmod +x /home/buildpiper/build.sh

# Environment variables
ENV APPLICATION_NAME="" \
    ORGANIZATION="" \
    SOURCE_KEY="gitleak" \
    FORMAT_ARG="json" \
    OUTPUT_ARG="gitleaks.json" \
    REPORT_FILE_PATH="null" \
    MI_SERVER_ADDRESS="" \
    WORKSPACE='/bp/workspace'\
    ACTIVITY_SUB_TASK_CODE="BP-GIT-LEAKS-TASK" \
    VALIDATION_ACTION_FAILURE="WARNING" \
    SLEEP_DURATION="5s"

# Switch to non-root user
USER buildpiper

# Entry point
ENTRYPOINT ["./build.sh"]
