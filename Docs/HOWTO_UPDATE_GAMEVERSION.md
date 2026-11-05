# How to Update Game Versions for Mods

## 1. Submitting the Issue

1. Navigate to the **Issues** tab of this repository and click **New Issue**.
2. Select the **Update gameVersion** template.
3. Fill out the required fields:
   - **Version number**: Enter the exact Nuclear Option Game Version Value you wish to apply (e.g., `0.34.2`).
   - **MOD IDs**: Enter the Mod IDs for all the mods that you want to update. Please put **one value per line** (e.g., `com.fake.modname`).

4. Submit the issue.

## 2. Automated Processing

Once the ticket is approved, the following automated steps occur:
- The system parses the provided **Version number** and **MOD IDs**.
- It validates that the Version number is a valid format and that the Mod IDs match existing files in the `modManifests` directory.
  - *Note: If validation fails, the bot will leave a comment on the issue with the exact error message and halt the process.*
- If validation succeeds, the system temporarily saves the requested updates to a cache.
- The `Hourly Update` workflow later runs and updates the manifests in the `modManifests` directory, updating the `gameVersion` property of the **latest** artifact for each requested Mod ID.
- Finally, the bot commits the changes back to the main branch and automatically closes the parent issue as "completed".
