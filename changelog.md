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
    - Enhanced the credential scanning logic by generating a CSV report (`cred_scanner.csv`) and adding a summary file (`${cred_scanner}_sum.csv`) that includes fix.
    - Ensured that the `cred_scanner.csv` file always contains either the leak data or a "no-leaks" message.
        
- **Integration with MI Reporting:**
    - Integrated MI data generation and sending functionality to communicate the results with the MI server, improving traceability and reporting.
    
- **Docker Image Updates:**
    - Updated base image and dependencies for improved performance and compatibility.

- **Bug Fixes:**
    - Fixed issues with report formatting for compatibility with downstream tools.

    ---

   **"For any issues or feature requests, please add them to our repository's issue tracker: [BP-GIT-LEAKS-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-GIT-LEAKS-STEP)."**