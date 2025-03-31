# **Change Log**

| **Version** | **Release Date** | **Maintainer** | **New Features & Enhancements** | **Bug Fixes** |
|-------------|------------------|----------------|----------------------------------|---------------|
| `0.3-mi`    | *null*           | [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj) | Initial script to scan Git repositories for credentials using Gitleaks. | N/A |
| `0.7.3`     | 15-01-2025       | [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj) | Improved Git repository scanning, MI reporting integration, Docker image updates. | Fixed issues with report formatting for compatibility with downstream tools. |
| `0.7.4`     | 15-01-2025       | [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj) | Added `tty-table` for formatted report display, reduced Docker image size, simplified environment variable setup. | N/A |
| `0.7.5`     | 26-02-2025       | [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj) | Replaced `tty-table` with Python-based solution for report formatting, reduced Docker image size further. | N/A |
| `0.7.6`     | 26-02-2025       | [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj) | Upgraded base image, improved Python-based report formatting, optimized file structure & permissions. | N/A |
| `0.7.7`     | 27-02-2025       | [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj) | Enhanced secret detection with redaction, optimized reporting output. | N/A |
| `0.7.8`     | 27-02-2025       | [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj) | Added logging message, updated report handling to copy all reports to the execution directory. | N/A |
| `0.7.9`     | 01-04-2025       | [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj) | Enhanced commit range scanning, improved report summarization, optimized dependency management, improved logging. | Fixed empty report handling, improved error handling. |

---

## **Details for Each Version**

### **Version: `0.3-mi`**
- **Release Date:** *null*
- **Maintainer:** [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)
- **New Features & Enhancements:**
  - Initial script to scan Git repositories for credentials using Gitleaks.
  - Logging integration with `logInfoMessage` and `logErrorMessage` for better visibility.
  - Automatic creation of reports directory if it doesn't exist.
  - Execution of Gitleaks with customizable report format and output path.
  - Aggregation of scan results by RuleID and exporting to `cred_scanner.csv`.
  - Handling of empty scan results by adding "no-leaks" to the report.
  - Base64 encoding of the scan report for data transmission.
  - Metadata integration for application, environment, service, organization, and source key.
  - Generation and sending of MI data to the specified MI server.
  - Error handling when the codebase directory does not exist.
  - Task status management and reporting using `saveTaskStatus`.

---

### **Version: `0.7.3`**
- **Release Date:** 15-01-2025
- **Maintainer:** [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)
- **New Features & Enhancements:**
  - Improved Git repository scanning by generating a CSV report (`cred_scanner.csv`) and adding a summary file (`cred_scanner_sum.csv`) with the total count of leaks.
  - Integrated MI data generation and sending functionality to communicate results with the MI server.
  - Updated base image and dependencies for improved performance and compatibility.
- **Bug Fixes:**
  - Fixed issues with report formatting for compatibility with downstream tools.

---

### **Version: `0.7.4`**
- **Release Date:** 15-01-2025
- **Maintainer:** [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)
- **New Features & Enhancements:**
  - Added `tty-table` for formatted report display.
  - Reduced Docker image size by combining package installations and cleanup steps.
  - Simplified environment variable setup with default values for key variables.
  - Ensured executable permissions for the `build.sh` script.

---

### **Version: `0.7.5`**
- **Release Date:** 26-02-2025
- **Maintainer:** [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)
- **New Features & Enhancements:**
  - Replaced `tty-table` with a Python-based solution for report formatting using the `tabulate` library.
  - Reduced Docker image size further by removing Node.js and npm dependencies.
  - Improved performance and readability of reports with the new Python-based approach.
  - Enhanced security by removing unnecessary dependencies and improving environment variable handling.

---

### **Version: `0.7.6`**
- **Release Date:** 26-02-2025
- **Maintainer:** [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)
- **New Features & Enhancements:**
  - Upgraded base image to the latest version for compatibility with recent security patches.
  - Improved Python-based report formatting with a dedicated virtual environment for dependencies.
  - Optimized file structure and permissions for better organization and execution.

---

### **Version: `0.7.7`**
- **Release Date:** 27-02-2025
- **Maintainer:** [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)
- **New Features & Enhancements:**
  - Enhanced secret detection with redaction sensitivity at a 90% threshold.
  - Optimized reporting output to ensure sensitive information is masked while maintaining actionable insights.

---

### **Version: `0.7.8`**
- **Release Date:** 27-02-2025
- **Maintainer:** [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)
- **New Features & Enhancements:**
  - Added logging messages for better traceability.
  - Updated report handling to copy all reports to the execution directory.

---

### **Version: `0.7.9`**
- **Release Date:** 01-04-2025
- **Maintainer:** [Email](mukul.joshi@opstree.com), [GitHub](https://github.com/mukulmj)
- **New Features & Enhancements:**
  - Enhanced commit range scanning with dynamic calculation based on `MAX_COMMITS`.
  - Improved report summarization by adding a summary file (`cred_scanner_sum.csv`).
  - Integrated a Python script (`print_table.py`) for better report display.
  - Optimized dependency management with a Python virtual environment.
  - Added detailed logging for each step of the scanning process.
- **Bug Fixes:**
  - Fixed empty report handling to ensure completeness.
  - Improved error handling for scenarios like missing codebase directories or invalid commit ranges.

---

**For any issues or feature requests, please add them to our repository's issue tracker: [BP-GIT-LEAKS-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-GIT-LEAKS-STEP).**
