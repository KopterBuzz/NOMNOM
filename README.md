# NOMNOM - Nuclear Option Managed & Neatly Organised Manifest

NOMNOM is a self-updating package manifest registry that Mod Manager Applications can use to source Nuclear Option Mod Packages.

NOMNOM can also register mod dependencies, incompatibilities, and add-ons to other Mods such as Voice Packs etc.

### DISCLAIMER

NOMNOM is a Community Project, and is not affiliated with Shockfront Studios, the developer of Nuclear Option.

### Current known Mod Manager Projects that use NOMNOM:

- [NOMM - Nuclear Option Mod Manager](https://github.com/Combat787/NuclearOptionModManager/) - [DOWNLOAD](https://github.com/Combat787/NuclearOptionModManager/releases/latest)

### Mod Submission Acceptance Policy:

- If your Mod contains custom DLL files, those DLL files Must Be Open-Sourced. Submission requests that do not comply will be denied.
  - Clarification: If your mod is an AddOn, e.g. a Blueprinter Aircraft Mod, or a Voice Pack, or similar AND Does Not contain any Custom DLL files, there is no cause for concern.

- If your Mod is found to be containing any malicious code or otherwise making unwarranted changes to the users' computers, all your submissions will be delisted and all your future submission requests will be denied. We have Zero Tolerance for any breaches.

- If Custom DLLs in your Mod Release(s) are found to be inconsistent with the Source Code (e.g. containing additional code that is not present in the Available Source code for the Open-Sourced DLL), all your submissions will be delisted and all your future submission requests will be denied. We have Zero Tolerance for any breaches.

- In order for NOMNOM to automatically discover new Mod Releases for Registered Mods, they must be available as GitHub Repository Release Package. If you use a different delivery method, you must submit a Pull Request to get New Releases registered. Follow [these instructions.](SCHEMA.md#how-to-contribute-mod-manifests)
- GitHub Repositories for your Mods should contain releases for ONLY ONE mod per Repository. Do not put releases for multiple mods under one Repository.
- If Your Mod Release(s) contain multiple Release Assets, the first Release Asset on the top of the list must be the one intended for NOMNOM.
  - The Release Asset must contain all the content for the Mod to function, with exception of dependency or extension relationships, aka other Mod(s) that Your Mod(s) rely on to function. See [Schema Documentation](SCHEMA.md#how-to-contribute-mod-manifests) for additional details on this.
  - If your Mod consists of Multiple Files, upload the Release Asset as a Compressed Archive (e.g. zip,rar,7z)
- Your Mod Release(s) must have a valid tagName that follows some acceptable versioning practice that is easy to parse (e.g. 1.2.3.4 or v1.2.3.4 or v2.0 or 2.0 etc).
- Your Mod(s) must work with BepInEx 5.

### How to Add your Nuclear Option Mod to NOMNOM
- You must Understand and Comply with the [Mod Submission Acceptance Policy](README.md#mod-submission-acceptance-policy)
- To create a new submission for registering a new Mod on NOMNOM, follow [these instructions.](SCHEMA.md#how-to-contribute-mod-manifests)

