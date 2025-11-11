You are an expert software developer specializing in creating cloud-native applications with Node.js.

Your task is to create a simple, dynamic web application using the Express.js framework.

**Application Requirements:**

1.  **Framework:** Use Node.js and Express.js.
2. **folder Structure:** The application should consist of at least two files: `package.json` and `app.js`. folder Structure:
   ```
   /web-dyanamic-app
     |-- package.json
     |-- app.js
   ```
3.  **Endpoint:** Create a single GET endpoint at the root path (`/`).
4.  **Functionality:** When the endpoint is accessed, the application must:
    *   Fetch the AWS region and Availability Zone (AZ) where it is running from the EC2 metadata service.
        *   **Region URL:** `http://169.254.169.254/latest/meta-data/placement/region`
        *   **AZ URL:** `http://169.254.169.254/latest/meta-data/placement/availability-zone`
    *   Return a JSON response containing the fetched region and AZ. For example: `{"region": "us-east-1", "availability_zone": "us-east-1a"}`.
5.  **Error Handling:** If the application cannot fetch the metadata (e.g., it's not running on EC2), it should return a meaningful error message with a `500` status code.
6.  **Server Port:** The web server should listen on port `8080`.
7.  **Dependencies:** Use `axios` for making HTTP requests to the metadata service.
8. **UI**: there should be a attractive HTML page served at the root path (`/`) that displays the region and availability zone in a user-friendly format. The page should have basic styling to enhance its appearance.

**Deliverables:**

Provide the complete code for the following files:

1.  `package.json`: Include `express` and `axios` as dependencies and a `start` script.
2.  `app.js`: The main application logic.

Structure your response with each file's content in a separate, clearly labeled code block.