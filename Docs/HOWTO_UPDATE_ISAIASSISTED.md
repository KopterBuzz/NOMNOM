# How to Update AI Assisted Status for Mods

## 1. Submitting the Issue

1. Navigate to the **Issues** tab of this repository and click **New Issue**.
2. Select the **Update isAiAssisted** template.
3. Fill out the required fields:
   - **Mod ID**: Enter the exact NOMNOM Mod ID you wish to update (e.g., `com.fake.mod.id`).
   - **AI Assisted**: Select whether this mod was created with substantial AI assistance (`True` or `False`) from the dropdown menu.

4. Submit the issue.

## 2. Automated Processing

Once the ticket is approved, the following automated steps occur:
- The system parses the provided **Mod ID** and **AI Assisted** selection.
- It validates that the Mod ID matches an existing file in the `modManifests` directory.
- It validates that the status is strictly one of the allowed values (`True` or `False`).
  - *Note: If validation fails, the bot will leave a comment on the issue with the exact error message and halt the process.*
- If validation succeeds, the system temporarily saves the requested update to a cache.
- The `Hourly Update` workflow later runs and updates the manifest in the `modManifests` directory, setting the new `isAiAssisted` property for the requested Mod ID.
- Finally, the bot commits the changes back to the main branch and automatically closes the parent issue as "completed".

