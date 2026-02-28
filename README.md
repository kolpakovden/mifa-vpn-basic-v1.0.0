## Mifa-VPN-basic

![Version](https://img.shields.io/badge/version-v1.0.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Ubuntu-orange)

Minimal, production-ready installer for Xray (VLESS + Reality)

> Default RU-friendly port: **8443**  
> Supports modern **Xray v26+ (Password/pbk format)**  
> Clean, minimal, no telemetry.

### Looking for Advanced Features?

If you need:

- Telegram-based user management  
- Monitoring (Grafana + Prometheus + Loki)  
- Modular architecture  
- Production-grade observability  

Check out the **MIFA VPN Platform** edition:
https://github.com/kolpakovden/mifa-vpn-platform

---

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
This installer supports both:
Legacy Xray output
```
Private key
Public key
```
Xray v26+ output
```
PrivateKey
Password
```
The script automatically detects and parses the correct format.

## Installation

```
git clone https://github.com/kolpakovden/MIFA-VPN-basic.git
cd MIFA-VPN-basic
sudo bash install.sh
```

## Security Note

Reality is a transport obfuscation layer, not a full anonymity system.
This project:
```
Protects traffic from simple DPI
Obfuscates TLS handshake
Helps bypass censorship in restrictive networks
```
This project does NOT:
```
Provide anonymity like Tor
Protect against endpoint compromise
Prevent server-side logging
Protect against traffic correlation attacks
```
You are responsible for proper operational security (OPSEC).

## Edition Comparison

| Feature | Basic | Platform |
|----------|--------|-----------|
| Xray (VLESS + Reality) |   ✅ |   ✅ |
| Telegram Bot |   ❌ |   ✅ |
| Monitoring Stack |   ❌ |   ✅ |
| Architecture | Monolithic | Modular |
| Target | Simple Setup | Production Infra |


## License
MIT

## Disclaimer

```
This project is intended for infrastructure automation and educational purposes.
Ensure compliance with local laws and regulations in your jurisdiction.
```
