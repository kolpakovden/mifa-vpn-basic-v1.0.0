# MIFA-VPN-basic v1.0.0

First stable public release of MIFA-VPN-basic - a minimal, production-ready installer for Xray (VLESS + Reality).

## Features
```
Minimal and clean Xray installer
VLESS + Reality configuration
RU-friendly default port: 8443
Configurable port (--port, --443, --8443)
Configurable SNI/target
Non-interactive mode (--non-interactive)
Automatic UUID generation
Automatic Reality key generation
Supports Xray v26+ (Password/pbk format)
systemd service integration
Ready-to-import VLESS URI output
```
## Reality Key Compatibility

This release supports both:
Legacy Xray output (Private key / Public key)
New Xray v26+ output (PrivateKey / Password)
The installer automatically detects and parses the correct format.

## Installation

git clone https://github.com/kolpakovden/MIFA-VPN-basic.git
cd MIFA-VPN-basic
sudo bash install.sh

## License
MIT

## Disclaimer

This project is intended for infrastructure automation and educational purposes.
Ensure compliance with local laws and regulations in your jurisdiction.
