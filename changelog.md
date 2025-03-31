### **Change Log for Docker Image: `registry.buildpiper.in/okts/gitleaks-scan:0.3-mi`**

---
**Version:** `0.3-mi`
**Release Date:** *null*  
**Maintainer:** *[Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

### Added

- Initial script to scan Git repositories for credentials using Gitleaks.
- Logging integration with logInfoMessage and logErrorMessage for better visibility.
- Automatic creation of reports directory if it doesn't exist.
- Execution of Gitleaks with customizable report format and output path.
- Aggregation of scan results by RuleID and exporting to cred_scanner.csv.
- Handling of empty scan results by adding no-leaks to the report.
- Base64 encoding of the scan report for data transmission.
- Metadata integration for application, environment, service, organization, and source key.
- Generation and sending of MI data to the specified MI server.
- Error handling when the codebase directory does not exist.
- Task status management and reporting using saveTaskStatus.

---

### **Change Log for Docker Image: `registry.buildpiper.in/okts/gitleaks-scan:0.7.3`**

---
**Version:** `0.7.3`
**Release Date:** *15-01-2025*  
**Maintainer:** *[Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

- **Improved Git Repository Scanning:**
  - Enhanced the credential scanning logic by generating a CSV report (`cred_scanner.csv`) and adding a summary file (`${cred_scanner}_sum.csv`) that includes the total count of leaks.
  - Ensured that the `cred_scanner.csv` file always contains either the leak data or a "no-leaks" message.

- **Integration with MI Reporting:**
  - Integrated MI data generation and sending functionality to communicate the results with the MI server, improving traceability and reporting.

- **Docker Image Updates:**
  - Updated base image and dependencies for improved performance and compatibility.

- **Bug Fixes:**
  - Fixed issues with report formatting for compatibility with downstream tools.

### **Change Log for Docker Image: `registry.buildpiper.in/okts/gitleaks-scan:0.7.4`**

---
**Version:** `0.7.4`
**Release Date:** *15-01-2025*  
**Maintainer:** *[Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*

### **New Features:**

- **Added tty-table for formatted report display**:  
  Now displays the Gitleaks scan results in a table format using `tty-table`. This allows for a more readable and visually appealing output.  
  *Note: Requires Node.js and npm. To install `tty-table`, run: `npm install -g tty-table`.*

  ```Dockerfile
  RUN apk add --no-cache --upgrade \
    bash jq gettext libintl curl nodejs npm && \
    npm install -g tty-table && \
    rm -rf /var/cache/apk/*
    ```

  ![attachments/csv_view.png](attachments/csv_view.png)

### **Improvements:**

- **Reduced Docker image size**:
  Combined package installations and cleanup steps into a single `RUN` command, optimizing the overall size of the Docker image.
  
- **Simplified environment variable setup**:  
  Set default values for important environment variables like `APPLICATION_NAME`, `ORGANIZATION`, `SOURCE_KEY`, `REPORT_FILE_PATH`, `FORMAT_ARG`, `OUTPUT_ARG` etc. for ease of use and customization at runtime.

- **Better file handling**:  
  Permissions on the `build.sh` script are ensured to be executable during the build process.

---

### **Change Log for Docker Image: `registry.buildpiper.in/okts/gitleaks-scan:0.7.5`**  

---
**Version:** `0.7.5`  
**Release Date:** *26-02-2025*  
**Maintainer:** *[Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*  

### **New Features:**

- **Replaced `tty-table` with a Python-based solution for report formatting**  
  - The dependency on Node.js and `tty-table` has been completely removed.  
  - Introduced a Python script (`print_table.py`) to handle CSV-based report formatting, improving compatibility and reducing unnecessary dependencies.  

  ```Dockerfile
  RUN apk add --no-cache --upgrade \
    bash jq gettext libintl curl python3 py3-pip && \
    pip install tabulate && \
    rm -rf /var/cache/apk/*
  ```

### **Improvements:**

- **Reduced Docker image size further**  
  - Removed Node.js and npm dependencies, making the image leaner.  
  - Optimized package installations to ensure minimal footprint.  

- **Improved performance and readability of reports**  
  - The new Python-based approach ensures a more structured and cleaner output.  
  - The `print_table.py` script leverages `tabulate` for displaying formatted reports.  

- **Enhanced security**  
  - Removed unnecessary dependencies, reducing potential attack vectors.  
  - Ensured better handling of environment variables and file permissions.  

---

### **Change Log for Docker Image: `registry.buildpiper.in/okts/gitleaks-scan:0.7.6`**  

---
**Version:** `0.7.6`  
**Release Date:** *26-02-2025*  
**Maintainer:** *[Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*  

### **New Features & Updates:**

- **Upgraded Base Image**  
  - Updated from `zricethezav/gitleaks:latest` to the latest available version.  
  - Removed `root` dependency from image.
  - Ensures compatibility with recent security patches and enhancements.  

- **Improved Python-based Report Formatting**  
  - The Python virtual environment is now used for managing dependencies.  
  - `tabulate` package is installed within a dedicated virtual environment for better isolation.  

  ```Dockerfile
  RUN python3 -m venv /opt/venv && \
      /opt/venv/bin/pip install --no-cache-dir tabulate
  ```

- **Optimized File Structure & Permissions**  
  - Updated the file copy locations for better organization:  
    - `BP-BASE-SHELL-STEPS` now resides in `/opt/buildpiper/shell-functions/`.  
    - `BP-BASE-SHELL-STEPS/data` is moved to `/opt/buildpiper/data`.  
  - Ensured correct execution permissions for scripts.  

- **Refactored Environment Variable Management**  
  - Simplified variable structure for improved readability and maintainability.  
  - Set defaults for key environment variables used in the scan process.

---

### **Change Log for Docker Image: `registry.buildpiper.in/okts/gitleaks-scan:0.7.7`**  

**Version:** `0.7.7`  
**Release Date:** *27-02-2025*  
**Maintainer:** *[Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*  

---

### **New Updates & Enhancements:**  

- **Enhanced Secret Detection with Redaction**  
  - The `gitleaks` command has been updated to include **redaction sensitivity** at a **90% threshold**.  
  - This helps mask sensitive data in reports while maintaining detection accuracy.  

  **Updated Command:**

  ```sh
  gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG -v --redact=90
  ```

  **Previous Command:**

  ```sh
  gitleaks detect --exit-code 1 --report-format $FORMAT_ARG --report-path reports/$OUTPUT_ARG -v
  ```

---

### **Improvements:**

- **Better Compliance & Security**  
  - The `--redact=90` flag ensures that **high-confidence secrets** are redacted in reports, reducing exposure risks.  
  - Aligns with best practices for secret scanning and compliance with security policies.  

- **Optimized Reporting Output**  
  - Ensures sensitive information is properly masked while still providing actionable insights.  

---

### **Change Log for Docker Image: `registry.buildpiper.in/okts/gitleaks-scan:0.7.8`**  

**Version:** `0.7.8`  
**Release Date:** *27-02-2025*  
**Maintainer:** *[Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)*  

#### **Changes & Enhancements:**  
- Added logging message:

  ```bash
  logInfoMessage "Updating reports in /bp/execution_dir/${GLOBAL_TASK_ID}......."
  ```

- Updated report handling to copy all reports to the execution directory:  

  ```bash
  cp -rf reports/* /bp/execution_dir/${GLOBAL_TASK_ID}/
  ```
  
- Ensures all reports are stored in the workspace for better traceability.  

---

**"For any issues or feature requests, please add them to our repository's issue tracker: [BP-GIT-LEAKS-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-GIT-LEAKS-STEP)."**
