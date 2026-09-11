# How to Update Mod Images

## 1. Submitting the Issue

1. Navigate to the **Issues** tab of this repository and click **New Issue**.
2. Select the **Update Mod Image URL** template.
3. Fill out the required fields:
   - **Mod ID**: Enter the exact NOMNOM Mod ID you wish to update (e.g., `com.fake.mod.id`).
   - **Image URL**: Enter the new image URL. The URL must point to a valid image file.
     - **Supported Formats:** JPG, PNG, WEBP, SVG ONLY.
     - **Size Limits:** Maximum resolution is 512x512 pixels.

4. Submit the issue.

## 2. Automated Processing

Once the ticket is approved, the following automated steps occur:
- The system parses the provided **Mod ID** and **Image URL**.
- It validates that the Mod ID matches an existing file in the `modManifests` directory.
- It downloads the image and verifies that it does not exceed the maximum resolution of 512x512 pixels.
  - *Note: If validation fails, the bot will leave a comment on the issue with the exact error message and halt the process.*
- If validation succeeds, the system calculates the image's `SHA-256` hash and temporarily saves the requested update to a cache.
- The `Hourly Update` workflow later runs and updates the manifest in the `modManifests` directory, setting the new `imageUrl` and `imageHash` properties for the requested Mod ID.
- Finally, the bot commits the changes back to the main branch and automatically closes the parent issue as "completed".
