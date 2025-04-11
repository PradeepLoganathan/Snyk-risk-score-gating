Snyk Risk Score CI/CD Gate Script
=================================

This script attempts to integrate Snyk's Risk Score into a CI/CD pipeline as a gating mechanism. It runs `snyk monitor` on a specified code directory, waits for a period, then queries the Snyk REST API to fetch issues and their associated Risk Scores. If the highest Risk Score found exceeds a defined threshold, the script exits with an error code, intended to fail the pipeline build.

**Disclaimer:** This script relies on timing and assumptions about Snyk's backend processing speed. Due to the asynchronous nature of `snyk monitor` and potential API latency, there is **no guarantee** that the Risk Score fetched immediately corresponds to the `snyk monitor` run initiated by this script. Use this script with caution and understand its limitations.

How it Works
------------

1.  **Configuration:** Loads necessary environment variables (`ORG_ID`, `PROJECT_ID`, `SNYK_API_TOKEN`, `RISK_THRESHOLD`) potentially from a `.env` file. Defines the target code directory (`TARGET_CODE_DIR`).
2.  **Prerequisites Check:** Verifies that `jq`, `curl`, and the `snyk` CLI are installed.
3.  **Get Commit Hash:** Retrieves the short commit hash from the specified `TARGET_CODE_DIR`.
4.  **Run `snyk monitor`:** Executes `snyk monitor` against the `TARGET_CODE_DIR`, providing the Organization ID, Project ID, and commit hash as the target reference. This command initiates a snapshot upload to Snyk.
5.  **Wait:** Pauses execution for a configurable `WAIT_TIME` (in seconds). This pause is an attempt to allow Snyk's backend to process the snapshot and update the API, but **sufficiency is not guaranteed**.
6.  **Fetch Issues via API:** Calls the Snyk REST API (`/orgs/{org_id}/issues`) to retrieve issues associated with the `PROJECT_ID`. It handles API pagination to fetch all issues.
7.  **Extract Max Risk Score:** Parses the API responses using `jq` to find the highest Risk Score (`priority.score` attribute) among all fetched issues.
8.  **Gating Logic:** Compares the `max_risk_score` against the `RISK_THRESHOLD`.
    -   If `max_risk_score > RISK_THRESHOLD`, the script prints an error message and exits with code 1.
    -   Otherwise, the script prints a success message and exits with code 0.

Limitations and Caveats
-----------------------

-   **Asynchronicity & Latency:** `snyk monitor` is asynchronous. The script finishing does not mean Snyk has finished processing the snapshot. API data might be stale due to backend processing and propagation delays. The `WAIT_TIME` is a guess and may not be long enough in all cases.
-   **No Direct Correlation:** The script relies on timing and the `PROJECT_ID` for correlation. `snyk monitor` does not output a unique scan/snapshot ID that can be used to reliably query the results of that specific run via the API.
-   **Risk Score Field:** The script correctly fetches the Risk Score from the `attributes.priority.score` field within the Issues API response, as documented by Snyk when the Risk Score feature is enabled.
-   **Alternative Approaches:** For more reliable CI/CD gating, consider:
    -   Using `snyk test` and gating on severity thresholds or other factors available in its synchronous output.
    -   Implementing a more complex webhook-based system that triggers the API check only after receiving a `project_snapshot` event from Snyk, indicating the snapshot processing is complete.

Setup
-----

### Prerequisites

Ensure the following tools are installed and available in your CI/CD environment's `PATH`:

-   [`jq`](https://www.google.com/search?q=%5Bhttps://jqlang.github.io/jq/download/%5D(https://jqlang.github.io/jq/download/)): Command-line JSON processor.
-   [`curl`](https://www.google.com/search?q=%5Bhttps://curl.se/%5D(https://curl.se/)): Command-line tool for transferring data with URLs.
-   [`snyk` CLI](https://www.google.com/search?q=%5Bhttps://docs.snyk.io/snyk-cli/install-or-update-the-snyk-cli%5D(https://docs.snyk.io/snyk-cli/install-or-update-the-snyk-cli)): Snyk Command Line Interface. Authenticate the CLI using `snyk auth`.
-   [`git`](https://www.google.com/search?q=%5Bhttps://git-scm.com/%5D(https://git-scm.com/)): Required to get the commit hash.

### Configuration

1.  **Environment Variables:** The script requires the following environment variables:

    -   `ORG_ID`: Your Snyk Organization ID.
    -   `PROJECT_ID`: The Snyk Project ID you want to associate the scan with (or let `snyk monitor` create/update).
    -   `SNYK_API_TOKEN`: Your Snyk API token (ensure it has necessary permissions). Keep this secure (e.g., using CI/CD secrets).
    -   `RISK_THRESHOLD`: The maximum acceptable Risk Score (e.g., `700`). Builds will fail if any issue's score exceeds this.

    You can optionally create a `.env` file in the same directory as the script to store these variables (ensure this file is in your `.gitignore` and not committed):dotenv ORG_ID=your-org-id PROJECT_ID=your-project-id SNYK_API_TOKEN=your-snyk-api-token RISK_THRESHOLD=750

2.  **Target Code Directory:** Modify the `TARGET_CODE_DIR` variable within the script to point to the correct path of the code repository you want to scan.

    Bash

    ```
    # Define the path to the code you want to scan
    # IMPORTANT: Replace this with the actual relative or absolute path
    TARGET_CODE_DIR="/path/to/your/code"

    ```

3.  **Wait Time (Optional):** Adjust the `WAIT_TIME` variable (in seconds) based on observed Snyk processing times for your projects. Default is 60 seconds. Remember, this is not a guarantee.

    Bash

    ```
    # Wait time in seconds after snyk monitor (adjust based on observation, but reliability is NOT guaranteed)
    WAIT_TIME=60

    ```

4.  **Snyk API Version (Optional):** Adjust the `SNYK_API_VERSION` date string if needed, using a recent date in `YYYY-MM-DD` format.

    Bash

    ```
    # Snyk API Version (use a recent date)
    SNYK_API_VERSION="2024-05-23" # Adjust date as needed

    ```

Usage
-----

Make the script executable:

Bash

```
chmod +x your_script_name.sh

```

Run the script from your CI/CD pipeline:

Bash

```
./your_script_name.sh

```

The script will exit with code 0 if the highest Risk Score is below or equal to the threshold, and exit with code 1 if it exceeds the threshold.

Contributing
------------

Contributions are welcome. Please open an issue or submit a pull request.

License
-------