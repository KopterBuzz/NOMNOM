# NOMNOM - Nuclear Option Managed & Neatly Organised Manifest

NOMNOM is a self-updating package manifest registry that Mod Manager Applications can use to source Nuclear Option Mod Packages.

NOMNOM can also register mod dependencies, incompatibilities, and add-ons to other Mods such as Voice Packs etc.

### Current known Mod Manager projects that use NOMNOM:

- [NOMM - Nuclear Option Mod Manager](https://github.com/Combat787/NuclearOptionModManager/) - [DOWNLOAD](https://github.com/Combat787/NuclearOptionModManager/releases/latest)

- [Yellowcake Mod Manager](https://github.com/NaghDiefallah/Yellowcake) - [DOWNLOAD](https://github.com/NaghDiefallah/Yellowcake/releases/latest)


### How to Add your Nuclear Option Mod to NOMNOM

To make NOMNOM aware of a new Mod, create an Issue on the [NOMNOM repository](https://github.com/KopterBuzz/NOModManifestTesting/issues) with the Mod's Details, or follow [these instructions.](SCHEMA.md#how-to-contribute-mod-manifests)

NOMNOM can self-update its registry, so it is able to automatically pick up new releases for Mods that it already knows about.

However, there are some basic requirements in order for NOMNOM to keep itself up to date in regards to the latest available versions of your Mod(s):
 - your Mod Release(s) must be available as GitHub Repository Release Package(s)
 - your Mod Release(s) should have one downloadable Asset per Release. If your mod consists of Multiple Files, upload the Release as a Compressed Archive (e.g. zip,rar,7z)
 - your Mod Release(s) must have a valid tagName that follows some acceptable versioning practice that is easy to parse (e.g. 1.2.3.4 or v1.2.3.4 or v2.0 or 2.0 etc)

 This is not directly related to the above, but at the moment Mod Manager software that depends on NOMNOM expects the following criteria also:
 - your Mod(s) must work with BepInEx 5

If you would like to help improving NOMNOM, follow [these instructions.](SCHEMA.md#how-to-contribute-anything-else)
