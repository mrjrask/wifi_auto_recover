# WiFi Auto-Recover Watchdog for Raspberry Pi

A lightweight systemd-based watchdog that automatically detects and repairs Wi-Fi disconnections on a Raspberry Pi.
Ideal for devices placed at the **edge of a Wi-Fi signal**, where the connection may drop and fail to recover on its own.

---

## 🧠 Overview

This script continuously monitors your Raspberry Pi’s Wi-Fi connection.
If the connection to your router or the internet is lost, it:

1. Detects the loss of network association or connectivity.
2. Logs the event (with timestamps) to a file in your home directory.
3. Disables and re-enables Wi-Fi every 60 seconds until the connection is restored.
4. Records how long recovery took.
5. Disables Wi-Fi power-saving mode to prevent flakiness on weak signals.
6. Keeps detailed system and user logs for diagnostics.

---

## ⚙️ Features

- ✅ Automatic detection of Wi-Fi loss (both association and internet reachability)
- 🔁 Auto-reconnect logic (down → up cycle every 60 s)
- 🕒 Logs how long recovery takes
- 🧾 Two log locations for different purposes:
  - `/var/log/wifi_auto_recover.log` – detailed system logs
  - `~/wifi_recovery.log` – concise summary of when recovery was needed and how long it took
- 🚫 Power-saving mode disabled at startup to improve reliability
- 🧩 Runs automatically at boot via systemd

---

## 📂 File Locations

| Purpose | File Path |
|----------|------------|
| Main Script | `/usr/local/bin/wifi_auto_recover.sh` |
| User Event Log | `~/wifi_recovery.log` |
| System Log | `/var/log/wifi_auto_recover.log` |
| Systemd Unit | `/etc/systemd/system/wifi-auto-recover.service` |

---

## 🛠️ Installation

### 1. Install dependencies
Most are preinstalled on Raspberry Pi OS, but run this to be safe:
```bash
sudo apt-get update
sudo apt-get install -y iw wireless-tools
```

### 2. Install the watchdog script
Copy the script into place and make it executable:
```bash
sudo install -Dm755 wifi_auto_recover.sh /usr/local/bin/wifi_auto_recover.sh
```

### 3. Install the systemd service unit
Copy the provided unit file and reload systemd:
```bash
sudo install -Dm644 systemd/wifi-auto-recover.service /etc/systemd/system/wifi-auto-recover.service
sudo systemctl daemon-reload
```

### 4. Enable and start the service
```bash
sudo systemctl enable --now wifi-auto-recover.service
```

The service will now start at boot and recover Wi-Fi automatically.

---

## ✅ Verifying operation
- Check the service status:
  ```bash
  systemctl status wifi-auto-recover.service
  ```
- Review the detailed log file:
  ```bash
  sudo tail -f /var/log/wifi_auto_recover.log
  ```
- Review the summary log in your home directory:
  ```bash
  tail -f ~/wifi_recovery.log
  ```

---

## 🔧 Troubleshooting tips
- **`status=203/EXEC`** – The script is missing or not executable. Ensure it exists at `/usr/local/bin/wifi_auto_recover.sh` and has the `755` permissions.
- **`Assignment outside of section`** – The unit file is malformed. Reinstall `systemd/wifi-auto-recover.service` so that it begins with `[Unit]`, `[Service]`, and `[Install]` sections as provided here.
- To manually restart Wi-Fi while debugging:
  ```bash
  sudo systemctl restart wifi-auto-recover.service
  ```

If problems persist, inspect `journalctl -u wifi-auto-recover.service` for detailed error messages.
