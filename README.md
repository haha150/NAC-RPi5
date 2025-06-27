# NAC-RPi4
Bash Script to Initialize a Raspberry Pi 4 for NAC Bypassing

This comprehensive bash script turns your **Raspberry Pi 4** into a powerful Wi-Fi hotspot and DHCP server. But it doesn't stop there! It also beefs up your Pi's security by configuring SSH and integrates advanced network tools like **NAC Bypass** and **SilentBridge** for specialized operations.

---

## ✨ Features

* **🌐 Wi-Fi Hotspot Creation:** Transforms your Raspberry Pi 4 into a dedicated access point with a custom SSID and WPA-PSK password.
* **📡 DHCP Server Configuration:** Sets up `isc-dhcp-server` to automatically assign IP addresses (192.168.200.2-100) to devices connecting to your hotspot.
* **🔒 SSH Security Hardening:** Overwrites the default `sshd_config` with a more secure setup. This includes disabling password authentication by default (except for your hotspot's subnet) and enforcing stronger ciphers and MACs.
* **⚙️ Static IP for `wlan0`:** Configures a static IP address for the `wlan0` interface (192.168.200.1) using `systemd-networkd` for reliable hotspot operation.
* **🛡️ NAC Bypass Tool Installation:** Installs and sets up the `nac_bypass` tool for advanced network access control evasion. This involves loading necessary kernel modules, enabling IP forwarding, and cloning the repository.
* **👻 SilentBridge Tool Installation:** Installs the `silentbridge` tool. It handles its specific Python 2.7 dependencies by creating a dedicated virtual environment, ensuring a clean setup.

---

## ⚠️ Prerequisites

Before running this script, make sure you have:

* **Raspberry Pi 4:** This script is specifically designed for the RPi 4. We assume there is a default wlan0 interface.
* **Kali OS Installation:** For the smoothest experience, start with a fresh Kali Linux ARM image. Tested for `kali-linux-2025.2-raspberry-pi-arm64.img`.
* **Internet Connectivity:** Your Pi needs an active internet connection during the script's execution to download packages and clone repositories.
* **Root Privileges:** The script modifies system files and services, so it must be run with `sudo`.
* **LAN USB Adapter:** For NAC bypassing to work, you must have a second LAN NIC (eth1) besides the native one (eth0). Easily achieved by purchasing a LAN USB adapter like [this one](https://amzn.eu/d/eYJzfUH).

> [!TIP]
> You may want to add a [hardened case with display](https://amzn.eu/d/90DKels) and [LTE USB dongle](https://amzn.eu/d/5NSOiOt). Totally optional though.

---

## 🚀 Getting Started

Follow these steps to get your Raspberry Pi configured:

### 1. Download the Script

You can clone the repository (if hosted on GitHub) or directly download the script:

```bash
git clone https://github.com/l4rm4nd/NAC-RPi4
cd NAC-RPi4
```
