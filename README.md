# NOMNOM - Nuclear Option Managed & Neatly Organised Manifest

NOMNOM is a self-updating package manifest registry that Mod Manager Applications can use to source Nuclear Option Mod Packages.

NOMNOM can also register mod dependencies, incompatibilities, and add-ons to other Mods such as Voice Packs etc.

### DISCLAIMER

NOMNOM is a Community Project, and is not affiliated with Shockfront Studios, the developer of Nuclear Option.

### Current known Mod Manager Projects that use NOMNOM:

- [NOMM - Nuclear Option Mod Manager](https://github.com/Combat787/NuclearOptionModManager/) - [DOWNLOAD](https://github.com/Combat787/NuclearOptionModManager/releases/latest)

### How to Add your Nuclear Option Mod to NOMNOM
- You must Understand and Comply with the [Mod Submission Acceptance Policy](README.md#mod-submission-acceptance-policy)
- To create a new submission for registering a new Mod on NOMNOM, follow [these instructions.](SCHEMA.md#how-to-contribute-mod-manifests)

### Mod Submission Acceptance Policy:

#### 1. Open-Source Mandate

If your Mod contains custom DLL or Executable Files, those DLL or Executable Files Must Be Open-Sourced and the Source Code must not contain any obfuscation. Submission requests that do not comply will be denied.
  - Clarifications:
    - If your mod is an AddOn, e.g. a Blueprinter Aircraft Mod, or a Voice Pack, or similar AND Does Not contain any Custom DLL or Executable Files, there is no cause for concern.
    - During periods of Retroactive Enforcement of the Mod Submission Acceptance Policy, Owners of any Mods that are found to be in breach of this clause will be contacted privately and asked to comply and will be given a reasonable Grace Period. Failing to take action to ensure compliance before the Grace Period's deadline expires will result in delisting the specific Mod(s) that breach this clause.

#### 2. Zero Tolerance Clauses

2.1

If your Mod is found to be containing any
  -  Obfuscated Code
  -  Malicious Code
  -  Making Unwarranted Changes to the users' computers
  -  Purposeful Interference with Nuclear Option in any way so that it might not launch or might terminate during runtime, or any other way to degrade the user experience on purpose

All your submissions will be delisted and all your future submission requests will be denied. We have Zero Tolerance for any breaches.

2.2

If Custom DLL or Executable Files in your Mod Release(s) are found to be inconsistent with the Source Code (e.g. containing additional code that is not present in the Available Source Code for the Open-Sourced DLLs or Executable Files), and these inconsistencies are found to be breaching Zero Tolerance Clause 2.1, all your submissions will be delisted and all your future submission requests will be denied. We have Zero Tolerance for any breaches.

#### 3. Licensing, Copyright and License Attribution

3.1

If your Mod uses, adapts or contains Third-Party Assets that are under any specific licenses, you must give credit to the Original Creator or Copyright Holder of the Assets, and display the Licenses under which these Assets were made available. Failure to do so may result in the specific Submission(s) that breach this clause being denied, or the specific Mod(s) found to be breaching this clause to be delisted.
  - Example: Using a 3d model of an aircraft or a vehicle that was made by someone else and released under e.g. Creative Commons License, but not crediting the author and displaying the License in the project's repository.

3.2

If you have been granted permission by Shockfront Studios to use in-game assets in your Mod project, you must also display proof of permission. Failure to do so may result in your submission being automatically denied.
  - Example: having Assets in your Mod project that are Ripped straight from the game, for any purpose. 

#### 4. Other Requirements
- In order for NOMNOM to automatically discover new Mod Releases for Registered Mods, they must be available as GitHub Repository Release Package.
  - If you use a different delivery method, you must submit a Pull Request to get New Releases registered. Follow [these instructions.](SCHEMA.md#how-to-contribute-mod-manifests)
- GitHub Repositories for your Mods should contain releases for ONLY ONE mod per Repository. Do not put releases for multiple mods under one Repository.
- If Your Mod Release(s) contain multiple Release Assets, the first Release Asset on the top of the list must be the one intended for NOMNOM.
  - The Release Asset must contain all the content for the Mod to function, with exception of dependency or extension relationships, aka other Mod(s) that Your Mod(s) rely on to function. See [Schema Documentation](SCHEMA.md#how-to-contribute-mod-manifests) for additional details on this.
  - If your Mod consists of Multiple Files, upload the Release Asset as a Compressed Archive (e.g. zip,rar,7z)
- Your Mod Release(s) must have a valid tagName that follows some acceptable versioning practice that is easy to parse (e.g. 1.2.3.4 or v1.2.3.4 or v2.0 or 2.0 etc).
- Your Mod(s) must work with BepInEx 5.

