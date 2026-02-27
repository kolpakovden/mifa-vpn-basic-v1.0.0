# MIFA-VPN-basic

Minimal installer for **Xray (VLESS + Reality)**.

**Goal:** one script → working VLESS Reality on **TCP 443**.

## Install
```
```bash
git clone https://github.com/<you>/MIFA-VPN-basic.git
cd MIFA-VPN-basic
sudo bash install.sh
```
At the end, the script prints a ready VLESS URI for your client.

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
