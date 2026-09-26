# CSign - Open Source iOS IPA Signing Tool

![Build Status](https://img.shields.io/github/actions/workflow/status/username/CSign/build.yml)
![iOS Version](https://img.shields.io/badge/iOS-14.0+-blue)
![Swift Version](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/License-MIT-green)

*(Screenshot placeholder)*

CSign is a powerful, on-device IPA signing tool for iOS devices, allowing you to sign and install IPAs directly on your phone without needing a computer.

## Features
- **App Library:** Manage your downloaded IPAs.
- **Certificate Management:** Import and manage `.p12` certificates and `.mobileprovision` profiles.
- **IPA Signing:** Sign IPAs locally on your device.
- **OTA Install:** Install signed IPAs over-the-air using a local server.
- **File Manager:** Built-in file browser to manage your apps, profiles, and certificates.

## Installation
You can install CSign in two ways:
1. **GitHub Actions:** Download the latest IPA from the Releases page.
2. **Sideloading:** Use AltStore, TrollStore, or your favorite sideloading tool to install the compiled IPA.

## Building from source
To build CSign from source:
1. Clone this repository.
2. Install XcodeGen (`brew install xcodegen`).
3. Run `xcodegen generate` to create the `.xcodeproj` file.
4. Open the project in Xcode and build.

## Usage
1. Import an IPA via the Files app integration.
2. Import your `.p12` and `.mobileprovision` files.
3. Select an IPA from the File Manager, sign it using your certificate, and tap Install.

## License
MIT

## Credits
Inspired by ESign and uses concepts from zsign.
