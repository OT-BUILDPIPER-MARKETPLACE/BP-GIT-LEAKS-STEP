FROM zricethezav/gitleaks:latest
# USER root

# Install dependencies
RUN apk --no-cache add \
    bash jq gettext libintl curl python3 py3-pip py3-virtualenv

# Create a virtual environment and install Python packages inside it
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir tabulate

# Set environment variables to use the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Copy files efficiently with correct permissions
COPY build.sh .
COPY print_table.py /usr/local/bin/print_table.py
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
ADD BP-BASE-SHELL-STEPS/data /opt/buildpiper/data
RUN chmod +x build.sh /usr/local/bin/print_table.py

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

ENTRYPOINT [ "./build.sh" ]
