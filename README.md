# evidrune

OTA release setup for the Evidrune Windows agent. Application source, enrollment
keys, telemetry, and signing private keys do not belong in this repository.

Devices download public release assets from **Yamikage-001/evidrune**. They use a
separate anonymous HTTPS client, so company device credentials are never sent to
GitHub. The updater checks the MSI's SHA-256, size, product UpgradeCode, newer
version, Windows Authenticode validity, and an administrator-approved signer.

## Bootstrap once

Install agent 0.10.6 or later through your normal administrative deployment
channel. Older agents have no OTA updater. Then run the app's
`Enable-ManagedUpdates.ps1` elevated with your trusted code-signing certificate
thumbprint and `-Repository Yamikage-001/evidrune`. The certificate thumbprint is
public information; its private key stays in your signing system.

## Prepare a release

1. Build and Authenticode-sign `EvidruneAgent.msi` using the organization's
   trusted code-signing certificate. Keep the MSI ProductVersion aligned with
   the release version, for example `0.10.6`.
2. Create a **draft** GitHub Release tagged `v0.10.6` and upload the signed MSI
   under the exact name `EvidruneAgent.msi`. Do not replace assets after publish.
3. Set the repository Actions variable `WINDOWS_SIGNER_THUMBPRINTS` to the
   approved certificate thumbprint, or semicolon-separated thumbprints during
   rotation. This contains public thumbprints, not a private key or password.
4. Run **Verify and publish Windows OTA** in Actions with the tag. It validates
   the signed MSI, generates `windows.json` directly from that file, and uploads
   the manifest. The default leaves the release in draft for review. Run with
   `publish=true` when you want to release it to devices.

The workflow refuses an unsigned MSI, a different product, a tag/version
mismatch, and changes to an already published release. No signing credentials
are required in this repository: signing happens before the MSI is uploaded.
For local verification you can run:

```powershell
./scripts/New-WindowsManifest.ps1 -MsiPath ./EvidruneAgent.msi -Version 0.10.6 -SignerThumbprints YOUR_CERTIFICATE_THUMBPRINT
```

## On devices

The SYSTEM task checks every six hours and installs verified newer packages
without a window or forced restart. Offline devices retry later. The app keeps
its Installed Apps entry and tray status, without a Start menu shortcut.
The stable manifest URL is:

`https://github.com/Yamikage-001/evidrune/releases/latest/download/windows.json`

It describes a versioned package at:

`https://github.com/Yamikage-001/evidrune/releases/download/v<VERSION>/EvidruneAgent.msi`

Do not publish an unsigned bootstrap MSI as an OTA release. A signed package and
device-side signer enrollment are required before automatic installation works.
The dashboard backend remains responsible for uninstall/reporting alerts.
