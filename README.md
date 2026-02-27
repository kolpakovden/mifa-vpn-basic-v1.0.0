# MIFA-VPN-basic

Minimal installer for **Xray (VLESS + Reality)**.  
RU-friendly default port: **8443** (because 443 may be unreliable under DPI).

## Install
```
```bash
git clone https://github.com/<you>/MIFA-VPN-basic.git
cd MIFA-VPN-basic
sudo bash install.sh
```
The script prints a ready-to-import VLESS URI.

## Presets
```
sudo bash install.sh --8443
sudo bash install.sh --443
sudo bash install.sh --port 12345
sudo bash install.sh --non-interactive --8443
```

## Paths

- Config: /usr/local/etc/xray/config.json
- Logs: /var/log/xray/
- Service: systemctl status xray

## Troubleshooting
```
journalctl -u xray -f
xray run -test -config /usr/local/etc/xray/config.json
ss -tuln | grep 443
```

## License
MIT

## Disclaimer

This project is provided for infrastructure automation purposes.
Ensure compliance with laws and regulations in your jurisdiction.
