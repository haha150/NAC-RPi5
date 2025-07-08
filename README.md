# NAC-RPi4
Bash Script to Initialize a Raspberry Pi 4 for Bridged-based 802.1x (NAC) Bypassing

> Classical 802.1x bypass using Linux bridges. Provides the ability to place a rogue device between a supplicant and authentication server without being detected, and to allow traffic to flow through the rogue device (where it can be sniffed). Network interactivity is provided using Source NAT (SNAT) at Layers 2 and 3.
>
> Defeats 802.1x-2004 only and does not work for 802.x-2010 / MACSEC.

---

## ✨ Features

* **🌐 Wi-Fi Hotspot Creation:** Transforms your Raspberry Pi 4 into a dedicated access point with a custom SSID and WPA-PSK password.
* **📡 DHCP Server Configuration:** Sets up `isc-dhcp-server` to automatically assign IP addresses (192.168.200.2-100) to devices connecting to your hotspot.
* **🔒 SSH Security Hardening:** Overwrites the default `sshd_config` with a more secure setup. This includes disabling password authentication by default (except for your hotspot's subnet) and enforcing stronger ciphers and MACs.
* **⚙️ Static IP for `wlan0`:** Configures a static IP address for the `wlan0` interface (192.168.200.1) using `systemd-networkd` for reliable hotspot operation.
* **👻 NAC Bypass Tool Installation:** Installs and sets up the `nac_bypass` tool for advanced network access control evasion. This involves loading necessary kernel modules, enabling IP forwarding, and cloning the repository.
* **🛡️ Huawei LTE Dongle Setup:** Installs management scripts and systemd services to manage LTE/VPN Out-of-Band (OOB) connections to bypass NAT and allow remote access. Makes use of [Huawei Hilink scripts](https://github.com/zbchristian/huawei_hilink_api) for SIM PIN and LTE connection management. Uses WireGuard for VPN.

---

## ⚠️ Prerequisites

Before running this script, make sure you have:

* **Raspberry Pi 4:** This script is specifically designed for the RPi 4. We assume there is a default wlan0 interface.
* **Kali OS Installation:** For the smoothest experience, start with a fresh Kali Linux ARM image. Tested for `kali-linux-2025.2-raspberry-pi-arm64.img`.
* **Internet Connectivity:** Your Pi needs an active internet connection during the script's execution to download packages and clone repositories.
* **Root Privileges:** The script modifies system files and services, so it must be run with `sudo`.
* **LAN USB Adapter:** For NAC bypassing to work, you must have a second LAN NIC (eth1) besides the native one (eth0). Easily achieved by purchasing a LAN USB adapter like [this one](https://amzn.eu/d/eYJzfUH).

> [!TIP]
> You may want to add a [hardened case with display](https://amzn.eu/d/90DKels) and [LTE USB dongle](https://amzn.eu/d/5NSOiOt). Totally optional though. For the TFT display, you must install the drivers from [here](https://github.com/lcdwiki/LCD-show-kali).

---

## 🚀 Getting Started

Follow these steps to get your Raspberry Pi configured:

### 1. Flash Kali Linux ARM x64 onto your RPi 4

Fetch the Kali Linux ISO and flash it onto your SD Card using RPI Imager.

- https://www.kali.org/get-kali/#kali-arm
- https://github.com/raspberrypi/rpi-imager

>[!TIP]
> Using RPI Imager you can configure a default username and password as well as enable OpenSSH!

>[!WARNING]
> Use a LAN cable and refrain from setting up WLAN.
>
> Please connect all hardware devices to the RPi already (LAN/LTE USB adapters).

### 2. Update

Install latest updates onto your RPi4:

````
sudo apt update && sudo apt upgrade -y && sudo reboot now
````

### 3. Download the Script and Run

You can clone this repository and run the script:

```bash
git clone https://github.com/l4rm4nd/NAC-RPi4 && cd NAC-RPi4
sudo chmod +x provision.sh
sudo ./provision.sh
```

### 4. Reboot

After the script has finished, please reboot your RPI4. You can remove the LAN cable from now on.

### 5. Connect to WiFi Hotspot

The RPi4 will spawn a wifi hotspot with your given SSID and password during installation.

Simply connect to the access point.

A DHCP server will be running, handing out client IP addresses from the range `192.168.200.2 - 100`.

### 6. SSH Access

#### Via WiFi Hotspot

Once connected to the wifi hotspot, you can access the RPi4's SSH network service on TCP/22.

The RPi4 will have the IP address `192.168.200.1`. Just connect with your favorite SSH client (e.g. MobaXTerm).

#### Via LTE + VPN

In case you make use of an LTE connection, you can store your WireGuard client profile at `/etc/wireguard/wg0.conf` and start a VPN connection via `sudo wg-quick up wg0`. Then, the RPi4 will be in the same VPN network as your operators (pentesters, red teamers etc.). This allows remote access into a compromised corporate's network, while using an Out-of-Band (OOB) LTE+Wireguard network channel. The WG VPN is not configured to automatically start. It's up to you to configure this.

>[!WARNING]
> SSH uses public key authentication for external networks per default. No password auth.
>
> You can adjust the `/etc/ssh/sshd_config` though and whitelist your VPN IP CIDR range for password authentication. See the last entries in the SSH config regarding `Match Address ...`.

### 7. Adjustments

1. Re-check the OpenSSH configuration at `/etc/ssh/sshd_config`.
2. Re-check the Huawei SIM PIN at `/home/<your-username>/huawei_hilink_api/example_huawei_hilink.sh`.
3. Place your Wireguard client profile at `/etc/wireguard/wg0.conf` and may configure VPN auto-connect after boot.
4. Ensure `legacy` versions are used and not nftables
   - `sudo update-alternatives --config iptables`
   - `sudo update-alternatives --config arptables`
   - `sudo update-alternatives --config ebtables`
5. Ensure kernel module is active
   - `echo br_netfilter | sudo tee -a /etc/modules`

### 8. NAC Bypass

Use the tools `/root/nac_bypass` to your advantage.

May read [this](https://luemmelsec.github.io/I-got-99-problems-but-my-NAC-aint-one/) blog post by LuemmelSec and [this wiki](https://github.com/s0lst1c3/silentbridge/wiki) by Gabriel Ryan to sharpen your NAC bypass understanding.

#### 6.1 - nac_bypass

[README](https://github.com/scipag/nac_bypass)

1. Connect the switch to eth0 (native LAN interface of RPi4)
2. Connect victim (e.g. printer) to eth1 (external USB LAN adapter)

Then start the nac bypass:

````bash
# by default it will treat the lower interface device as switch side, and the next one as victim
./nac_bypass_setup.sh -1 eth0 -2 eth1 -S -R

# script will ask to wait some time, so it is able to dump the needed info from the network traffic
# afterwards, you can proceed and for instance do an nmap scan on the network
````
