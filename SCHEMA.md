# Nuclear Option Mod Package Management Manifest Schema

The manifest items consist of two main models:
- Mod
- Artifact

Mod is the main manifest catlog item, which has Artifacts, that are versioned representations of the actual content for the game.

For Example:
- Mod Xyz.ExampleMod
    - Xyz.ExampleMod-1.11.0
    - Xyz.ExampleMod-1.10.1
    - Xyz.ExampleMod-1.9.9

This structure allows forming the following relationships:
- Dependency Chains
- Incompatibility Flags
- Add-On-Mod Relationships (such as Voice Packs for WSO Yappinator, or Tacview Asset Packs for modded content, for example)

To contribute your own Mod Manifests, please see [HOW TO CONTRIBUTE MOD MANIFESTS](#how-to-contribute-mod-manifests)

For a raw overview of the Schema, please check [Validation Schema.](./ValidationSchema.json)

For full detailed overview of the Schema, please continue reading.

## Mod Object Properties

### id

- REQUIRED
- Format: string
- IDEALLY, This should be the AssemblyName of the BepInEx Plugin DLL
- If the Mod is not a BepInEx Plugin, but rather a content or utility, it should conform to this structure:

    ```"ModAssemblyName.UniqueRelevantString"```

    e.g

    ```"NOBlackBox.VanillaTacviewAssetPack"```

### displayName

- REQUIRED
- Format: string
- This is the Human Readable Name of the Mod

### description

- REQUIRED
- Format: string
- This is a brief descritpion of what the Mod does

### tags

- format: array of strings
- different tags, sucha as "QoL","Art","Aircraft","Terrain","Flavor","Server"

### infoUrl

- REQUIRED
- format: URI
- This should be a link to a site where more information is available about the mod e.g. a GitHub Page, or similar.

### authors

- format: array of strings
- this should be a list of authors who created the Mod

## Artifact Object Properties

### type

- REQUIRED
- Format: string
- type of Mod. currently considering following types to be supported:
    - plugin: BepInEx Plugin
    - addOn: Add-On or extension for another Mod, such as a voice or texture pack etc.
    - utility: anything that extends the game but runs as a separate process, outside the application's domain

### fileName

- REQUIRED
- Format: string
- name of the actual downloadable content file. Should be an archive, such as zip, rar, 7z.
### hash

- REQUIRED
- format: sha256 hash string, as copy-pastable from GitHub Releases: ```sha256:yourfilehashgoeshere```
- sha256 hash of the aforementioned downloadable content file

### gameVersion

- REQUIRED
- Format: Version as string
- This is the latest game version the mod supports e.g. ```"0.32"```

### version

- REQUIRED
- Format: Version as string
- THIS MUST MATCH THE VERSION IN THE DLL IN ITS METADATA IF Artifact Type = MOD

### category

- REQUIRED
- Format: string
- This is the category if the release e.g. Release or Pre-Release
- This is to allow users to optionally download a perhaps Unstable Pre-Release, or get the latest stable version.

### extends

- REQUIRED IF
    - CATEGORY IS addOn
- Format: Object
```
id : Mod id as string
version : Mod version as string
```
id must be the known Mod id of the mod this extends, as seen in the Manifest

version must be the minimum version this extension is compatible with

### dependencies

- REQUIRED IF
    - MOD HAS DEPENDENCIES
- Format: Array of Objects
```
id : Mod id as string
version : Mod version as string
```
id must be the known Mod id of the mod this depends on, as seen in the Manifest

version must be the minimum version this extension is compatible with

### incompatibilities

- REQUIRED IF
    - MOD IS KNOWN TO BE INCOMPATIBLE WITH OTHER MODS
- Format: Array of Objects
```
id : Mod id as string
version : Mod version as string
```
id must be the known Mod id of the mod this is incompatible with, as seen in the Manifest

version must be the latest known version this mod is incompatible with

## HOW TO CONTRIBUTE MOD MANIFESTS

1. Fork the repository (check fork all branches)
2. Check out the ```Staging``` branch to make sure you are working on the correct branch

    (branch protection rules will prevent you to submit PRs to main)

3. Create your own mod manifest(s) based on the schema described above
4. Submit a pull request to the staging branch
5. Github Actions Workflow will validate the Schema and Content, then declare the PR allowed to merge if successful
6. A Human will review and approve the merge is no issues found