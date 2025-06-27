#!/bin/bash

# This script automates the setup of a Wi-Fi hotspot and DHCP server on a Raspberry Pi 4,
# based on the guide from https://luemmelsec.github.io/I-got-99-problems-but-my-NAC-aint-one/
# It also configures SSH for enhanced security, installs the nac_bypass tool,
# and installs the silentbridge tool.

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'
BOLD='\033[1m'

# Emojis
SUCCESS_EMOJI="✅"
ERROR_EMOJI="❌"
WARNING_EMOJI="⚠️"
INFO_EMOJI="ℹ️"
STEP_EMOJI="➡️"

# Function to display error messages and exit
error_exit() {
    echo -e "${ERROR_EMOJI} ${RED}Error: $1${RESET}" >&2
    exit 1
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root. Please use 'sudo'."
fi

echo -e "${BOLD}${CYAN}Welcome to the Raspberry Pi Hotspot, DHCP, NAC Bypass, and SilentBridge Setup Script!${RESET}"
echo -e "${CYAN}----------------------------------------------------------------------------------${RESET}"

# --- User Input for Hotspot Details ---
echo -e "${INFO_EMOJI} ${BLUE}Please provide details for your Wi-Fi Hotspot:${RESET}"
read -p "Enter the desired Wi-Fi Hotspot Name (SSID): " WIFI_SSID
if [ -z "$WIFI_SSID" ]; then
    error_exit "Wi-Fi SSID cannot be empty."
fi

read -s -p "Enter the desired Wi-Fi Password (WPA-PSK, min 8 characters): " WIFI_PASSWORD
echo
if [ -z "$WIFI_PASSWORD" ] || [ ${#WIFI_PASSWORD} -lt 8 ]; then
    error_exit "Wi-Fi Password cannot be empty and must be at least 8 characters long."
fi

echo -e "\n${BOLD}${CYAN}--- Starting installation and configuration ---${RESET}\n"

# --- Step 1: Install required packages for Hotspot/DHCP ---
echo -e "${STEP_EMOJI} ${BLUE}1. Installing isc-dhcp-server and hostapd...${RESET}"
apt-get update || error_exit "Failed to update package lists."
apt-get install -y isc-dhcp-server hostapd || error_exit "Failed to install required packages."
echo -e "${SUCCESS_EMOJI} ${GREEN}isc-dhcp-server and hostapd installed.${RESET}\n"

# --- Step 2: Enable and unmask services ---
echo -e "${STEP_EMOJI} ${BLUE}2. Enabling and unmasking services...${RESET}"
systemctl enable isc-dhcp-server || error_exit "Failed to enable isc-dhcp-server."
systemctl unmask hostapd || error_exit "Failed to unmask hostapd."
systemctl enable hostapd || error_exit "Failed to enable hostapd."
echo -e "${SUCCESS_EMOJI} ${GREEN}Services enabled and unmasked.${RESET}\n"

# --- Step 3: Configure DHCP Server (dhcpd.conf) ---
echo -e "${STEP_EMOJI} ${BLUE}3. Configuring /etc/dhcp/dhcpd.conf...${RESET}"
DHCPD_CONF="/etc/dhcp/dhcpd.conf"
cat <<EOL > "$DHCPD_CONF"
default-lease-time 600;
max-lease-time 7200;
subnet 192.168.200.0 netmask 255.255.255.0 {
range 192.168.200.2 192.168.200.100;
option subnet-mask 255.255.255.0;
option broadcast-address 192.168.200.255;
}
EOL
if [ $? -ne 0 ]; then error_exit "Failed to write $DHCPD_CONF."; fi
echo -e "${SUCCESS_EMOJI} ${GREEN}$DHCPD_CONF configured.${RESET}\n"

# --- Step 4: Configure Hostapd (hostapd.conf) ---
echo -e "${STEP_EMOJI} ${BLUE}4. Configuring /etc/hostapd/hostapd.conf...${RESET}"
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"

# Warning: Remove existing wlan0 configurations if they exist
echo -e "   ${INFO_EMOJI} ${BLUE}Checking for existing wlan0 network configurations...${RESET}"
if [ -f "/etc/netplan/50-cloud-init.yaml" ]; then
    echo -e "   ${WARNING_EMOJI} ${YELLOW}Removing /etc/netplan/50-cloud-init.yaml...${RESET}"
    rm /etc/netplan/50-cloud-init.yaml || echo -e "   ${WARNING_EMOJI} ${YELLOW}Warning: Failed to remove /etc/netplan/50-cloud-init.yaml. Manual intervention might be needed.${RESET}"
fi
echo -e "   ${INFO_EMOJI} ${BLUE}If you have configured wlan0 manually or via Raspberry Pi Imager, you might need to remove it via 'nmtui'.${RESET}"


cat <<EOL > "$HOSTAPD_CONF"
interface=wlan0
#driver=nl80211
ssid=${WIFI_SSID}
hw_mode=g
channel=6
ieee80211n=1
ieee80211d=1
country_code=DE
#wme_enabled=1
wmm_enabled=1
auth_algs=1
ignore_broadcast_ssid=0
macaddr_acl=0
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=${WIFI_PASSWORD}
EOL
if [ $? -ne 0 ]; then error_exit "Failed to write $HOSTAPD_CONF."; fi
echo -e "${SUCCESS_EMOJI} ${GREEN}$HOSTAPD_CONF configured with provided SSID and password.${RESET}\n"

# --- Step 5: Validate interface name in isc-dhcp-server default file ---
echo -e "${STEP_EMOJI} ${BLUE}5. Configuring /etc/default/isc-dhcp-server...${RESET}"
DEFAULT_DHCP_SERVER="/etc/default/isc-dhcp-server"
sed -i 's/^INTERFACESv4=.*$/INTERFACESv4="wlan0"/' "$DEFAULT_DHCP_SERVER"
if ! grep -q 'INTERFACESv4="wlan0"' "$DEFAULT_DHCP_SERVER"; then
    echo 'INTERFACESv4="wlan0"' >> "$DEFAULT_DHCP_SERVER"
fi
if [ $? -ne 0 ]; then error_exit "Failed to configure $DEFAULT_DHCP_SERVER."; fi
echo -e "${SUCCESS_EMOJI} ${GREEN}$DEFAULT_DHCP_SERVER configured for wlan0.${RESET}\n"

# --- Step 6: Create/Update systemd service for isc-dhcp-server ---
echo -e "${STEP_EMOJI} ${BLUE}6. Creating/Updating /etc/systemd/system/isc-dhcp-server.service...${RESET}"
SYSTEMD_DHCP_SERVICE="/etc/systemd/system/isc-dhcp-server.service"
cat <<EOL > "$SYSTEMD_DHCP_SERVICE"
[Unit]
Description=ISC DHCP Server
After=network-pre.target
Wants=network-pre.target
Requires=network-pre.target
Requires=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device
After=hostapd.service

[Service]
ExecStart=/etc/init.d/isc-dhcp-server start
ExecStop=/etc/init.d/isc-dhcp-server stop
Type=forking
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL
if [ $? -ne 0 ]; then error_exit "Failed to write $SYSTEMD_DHCP_SERVICE."; fi
echo -e "${SUCCESS_EMOJI} ${GREEN}$SYSTEMD_DHCP_SERVICE created/updated.${RESET}\n"

# --- Step 7: Configure wlan0 static IP with systemd-networkd ---
echo -e "${STEP_EMOJI} ${BLUE}7. Configuring wlan0 static IP with systemd-networkd...${RESET}"
SYSTEMD_NETWORK_DIR="/etc/systemd/network"
mkdir -p "$SYSTEMD_NETWORK_DIR" || error_exit "Failed to create $SYSTEMD_NETWORK_DIR."
NETWORK_CONF="$SYSTEMD_NETWORK_DIR/10-wlan0-static.network"

cat <<EOL > "$NETWORK_CONF"
[Match]
Name=wlan0

[Network]
Address=192.168.200.1/24
EOL
if [ $? -ne 0 ]; then error_exit "Failed to write $NETWORK_CONF."; fi
echo -e "   ${SUCCESS_EMOJI} ${GREEN}$NETWORK_CONF created.${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}Enabling and restarting systemd-networkd...${RESET}"
systemctl enable systemd-networkd || error_exit "Failed to enable systemd-networkd."
systemctl restart systemd-networkd || echo -e "${WARNING_EMOJI} ${YELLOW}Warning: Failed to restart systemd-networkd. Check logs or reboot.${RESET}"
echo -e "   ${SUCCESS_EMOJI} ${GREEN}systemd-networkd enabled and restart attempted.${RESET}\n"

# --- Step 8: Reload systemd, enable, and restart services ---
# Adjusted numbering from previous step
echo -e "${STEP_EMOJI} ${BLUE}8. Reloading systemd daemon, enabling and restarting services...${RESET}"
systemctl daemon-reload || error_exit "Failed to reload systemd daemon."
# Hostapd and isc-dhcp-server restart handled here as well, although already attempted.
# This ensures they pick up the wlan0 configuration.
systemctl restart hostapd || echo -e "${WARNING_EMOJI} ${YELLOW}Warning: Failed to restart hostapd. Check logs after reboot.${RESET}"
systemctl restart isc-dhcp-server || echo -e "${WARNING_EMOJI} ${YELLOW}Warning: Failed to restart isc-dhcp-server. Check logs after reboot.${RESET}"
# Disable network manager as it mangles with hostapd and causes IEEE 802.11: disassociated
sudo systemctl disable NetworkManager || echo -e "${WARNING_EMOJI} ${YELLOW}Warning: Failed to disable NetworkManager. Check logs after reboot.${RESET}"
echo -e "${SUCCESS_EMOJI} ${GREEN}Services reloaded and restarted (if possible).${RESET}\n"


# --- Step 9: Configure SSH properly (overwriting) ---
echo -e "${STEP_EMOJI} ${BLUE}9. Configuring /etc/ssh/sshd_config (overwriting existing file)...${RESET}"
SSHD_CONF="/etc/ssh/sshd_config"

# Backup original sshd_config
cp "$SSHD_CONF" "${SSHD_CONF}.bak_$(date +%Y%m%d%H%M%S)"
echo -e "   ${INFO_EMOJI} ${BLUE}Backup of $SSHD_CONF created at ${SSHD_CONF}.bak_$(date +%Y%m%d%H%M%S)${RESET}"

cat <<'EOF' > "$SSHD_CONF"
Protocol 2
AddressFamily any
Port 22
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# SSH Authentication
UsePAM yes
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
#PermitRootLogin no
HostbasedAuthentication no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
IgnoreRhosts yes

# SSH Authorized Keyfiles
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2

# SSH Session
TCPKeepAlive yes
ClientAliveInterval 600
ClientAliveCountMax 2
LoginGraceTime 60
MaxAuthTries 3
Compression no

# SSH Information Disclosure
DebianBanner no
PrintMotd no
PrintLastLog yes

# SSH Logging
LogLevel VERBOSE
SyslogFacility AUTH

# SSH Tunneling & Forwarding
AllowAgentForwarding no
AllowTcpForwarding yes
PermitTunnel yes
X11Forwarding no
PermitUserEnvironment no

# SSH File Mode & Ownership Checking
StrictModes yes
#UsePrivilegeSeparation yes # deprecated

# SSH Access Controls - Groups
#AllowGroups ssh
#AllowUsers ssh-user

# SSH Encryption Ciphers
# recommended from https://www.sshaudit.com/hardening_guides.html#ubuntu_20_04_lts
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr

# SSH Message Authentication Codes (MAC)
# recommended from https://www.sshaudit.com/hardening_guides.html#ubuntu_20_04_lts
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com

# SSH Host Key Algorithms
# recommended from https://www.sshaudit.com/hardening_guides.html#ubuntu_20_04_lts
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,rsa-sha2-256,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com

# SSH Key Exchange Algorithms
# recommended from https://www.sshaudit.com/hardening_guides.html#ubuntu_20_04_lts
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Allow older public key types
#PubkeyAcceptedKeyTypes=+ssh-rsa

# SSH Custom Network Configuration (Internal)
Match Address 192.168.200.0/24
    PasswordAuthentication yes
EOF
if [ $? -ne 0 ]; then error_exit "Failed to write $SSHD_CONF."; fi
echo -e "${SUCCESS_EMOJI} ${GREEN}$SSHD_CONF overwritten successfully.${RESET}\n"

echo -e "${STEP_EMOJI} ${BLUE}10. Restarting SSH service to apply changes...${RESET}"
systemctl restart ssh.service || echo -e "${WARNING_EMOJI} ${YELLOW}Warning: Failed to restart SSH service. Check for errors.${RESET}"
echo -e "${SUCCESS_EMOJI} ${GREEN}SSH service restart attempted.${RESET}\n"

# --- Step 11: Install and configure nac_bypass ---
echo -e "${STEP_EMOJI} ${BLUE}11. Installing and configuring nac_bypass tool...${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}11.1. Installing nac_bypass dependencies...${RESET}"
# Only install if running something other than Kali Linux, or if not sure, install anyway.
# This script is for RPi4, which could be running Kali, but ensuring dependencies are there.
apt-get install -y bridge-utils ethtool macchanger arptables ebtables iptables net-tools tcpdump git || error_exit "Failed to install nac_bypass dependencies."
echo -e "   ${SUCCESS_EMOJI} ${GREEN}nac_bypass dependencies installed.${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}11.2. Loading kernel module br_netfilter...${RESET}"
modprobe br_netfilter
if ! lsmod | grep -q br_netfilter; then
    echo -e "   ${WARNING_EMOJI} ${YELLOW}Warning: br_netfilter module not loaded. Manual intervention may be needed.${RESET}"
else
    echo -e "   ${SUCCESS_EMOJI} ${GREEN}br_netfilter module loaded.${RESET}"
fi

echo -e "   ${INFO_EMOJI} ${BLUE}11.3. Appending br_netfilter to /etc/modules...${RESET}"
if ! grep -q "br_netfilter" /etc/modules; then
    echo "br_netfilter" | tee -a /etc/modules || echo -e "   ${WARNING_EMOJI} ${YELLOW}Warning: Failed to append br_netfilter to /etc/modules.${RESET}"
else
    echo -e "   ${INFO_EMOJI} ${BLUE}br_netfilter already in /etc/modules.${RESET}"
fi
echo -e "   ${SUCCESS_EMOJI} ${GREEN}br_netfilter configuration complete.${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}11.4. Enabling IP forwarding in /etc/sysctl.conf...${RESET}"
SYSCTL_CONF="/etc/sysctl.conf"
if ! grep -q "^net.ipv4.ip_forward = 1" "$SYSCTL_CONF"; then
    echo "net.ipv4.ip_forward = 1" >> "$SYSCTL_CONF"
    echo -e "   ${INFO_EMOJI} ${BLUE}net.ipv4.ip_forward = 1 added to $SYSCTL_CONF.${RESET}"
else
    sed -i 's/^#net.ipv4.ip_forward = 1/net.ipv4.ip_forward = 1/' "$SYSCTL_CONF"
    echo -e "   ${INFO_EMOJI} ${BLUE}net.ipv4.ip_forward = 1 uncommented or ensured in $SYSCTL_CONF.${RESET}"
fi
sysctl -p || echo -e "   ${WARNING_EMOJI} ${YELLOW}Warning: Failed to apply sysctl changes immediately. Reboot will apply.${RESET}"
echo -e "   ${SUCCESS_EMOJI} ${GREEN}IP forwarding enabled.${RESET}"


echo -e "   ${INFO_EMOJI} ${BLUE}11.5. Cloning nac_bypass repository...${RESET}"
NAC_BYPASS_DIR="$HOME/nac_bypass"
if [ -d "$NAC_BYPASS_DIR" ]; then
    echo -e "   ${INFO_EMOJI} ${BLUE}$NAC_BYPASS_DIR already exists. Pulling latest changes...${RESET}"
    (cd "$NAC_BYPASS_DIR" && git pull) || echo -e "   ${WARNING_EMOJI} ${YELLOW}Warning: Failed to pull latest changes for nac_bypass.${RESET}"
else
    git clone https://github.com/scipag/nac_bypass "$NAC_BYPASS_DIR" || error_exit "Failed to clone nac_bypass repository."
fi
echo -e "   ${SUCCESS_EMOJI} ${GREEN}nac_bypass repository cloned/updated.${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}11.6. Setting permissions for nac_bypass_setup.sh...${RESET}"
chmod +x "$NAC_BYPASS_DIR/nac_bypass_setup.sh" || echo -e "   ${WARNING_EMOJI} ${YELLOW}Warning: Failed to set executable permissions for nac_bypass_setup.sh.${RESET}"
echo -e "   ${SUCCESS_EMOJI} ${GREEN}Permissions set for nac_bypass_setup.sh.${RESET}\n"


# --- Step 12: Install and configure silentbridge ---
echo -e "${STEP_EMOJI} ${BLUE}12. Installing and configuring silentbridge tool...${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}12.1. Installing silentbridge base dependencies...${RESET}"
apt-get install -y python2-dev git || error_exit "Failed to install silentbridge base dependencies."
echo -e "   ${SUCCESS_EMOJI} ${GREEN}silentbridge base dependencies installed.${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}12.2. Getting python2 pip...${RESET}"
pushd /tmp > /dev/null # Change to a temporary directory silently
wget -q https://bootstrap.pypa.io/pip/2.7/get-pip.py || error_exit "Failed to download get-pip.py."
python2.7 get-pip.py || error_exit "Failed to install pip for Python 2.7."
rm get-pip.py
popd > /dev/null # Go back to original directory silently
echo -e "   ${SUCCESS_EMOJI} ${GREEN}pip for Python 2.7 installed.${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}12.3. Installing virtualenv==20.15.1 for python2.7 venvs...${RESET}"
# Changed version to 20.15.1 and removed --break-system-packages as requested.
pip install virtualenv==20.15.1 --ignore-installed || error_exit "Failed to install virtualenv 20.15.1."
echo -e "   ${SUCCESS_EMOJI} ${GREEN}virtualenv 20.15.1 installed.${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}12.4. Cloning silentbridge repository...${RESET}"
SILENTBRIDGE_DIR="$HOME/silentbridge"
if [ -d "$SILENTBRIDGE_DIR" ]; then
    echo -e "   ${INFO_EMOJI} ${BLUE}$SILENTBRIDGE_DIR already exists. Pulling latest changes...${RESET}"
    (cd "$SILENTBRIDGE_DIR" && git pull) || echo -e "   ${WARNING_EMOJI} ${YELLOW}Warning: Failed to pull latest changes for silentbridge.${RESET}"
else
    git clone https://github.com/s0lst1c3/silentbridge "$SILENTBRIDGE_DIR" || error_exit "Failed to clone silentbridge repository."
fi
echo -e "   ${SUCCESS_EMOJI} ${GREEN}silentbridge repository cloned/updated.${RESET}"

echo -e "   ${INFO_EMOJI} ${BLUE}12.5. Creating venv for python2.7 and installing silentbridge dependencies...${RESET}"
if [ -d "$SILENTBRIDGE_DIR/venv2" ]; then
    echo -e "   ${INFO_EMOJI} ${BLUE}Existing venv2 detected. Recreating to ensure clean install.${RESET}"
    rm -rf "$SILENTBRIDGE_DIR/venv2"
fi

pushd "$SILENTBRIDGE_DIR" > /dev/null || error_exit "Failed to change directory to $SILENTBRIDGE_DIR."
virtualenv -p "$(which python2)" venv2 || error_exit "Failed to create python2 virtual environment."
source venv2/bin/activate || error_exit "Failed to activate venv2."

# Install dependencies within the virtual environment
pip install scapy==2.4.3 --ignore-installed || error_exit "Failed to install scapy."
pip install netifaces || error_exit "Failed to install netifaces."
pip install nanpy || error_exit "Failed to install nanpy."

deactivate # Deactivate virtual environment
popd > /dev/null # Go back to original directory
echo -e "   ${SUCCESS_EMOJI} ${GREEN}silentbridge and its dependencies installed in venv2 within $SILENTBRIDGE_DIR.${RESET}\n"

echo -e "${BOLD}${GREEN}----------------------------------------------------------------${RESET}"
echo -e "${BOLD}${GREEN}Setup complete!${RESET}"
echo -e "${BOLD}${GREEN}----------------------------------------------------------------${RESET}"
echo -e "${INFO_EMOJI} ${BLUE}Please reboot your Raspberry Pi for all changes to take full effect.${RESET}"
echo -e "The Wi-Fi hotspot '${BOLD}${WIFI_SSID}${RESET}${BLUE}' with password '${BOLD}${WIFI_PASSWORD}${RESET}${BLUE}' should be available after reboot.${RESET}"
echo -e "You can connect to it and devices should get IPs from 192.168.200.2-100.${RESET}"
echo -e "SSH access from 192.168.200.0/24 will allow password authentication, otherwise pubkey auth is required.${RESET}\n"

echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
echo -e "${BOLD}${CYAN}NAC Bypass Tool Information:${RESET}"
echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
echo -e "${INFO_EMOJI} ${BLUE}The 'nac_bypass' tool has been installed in: ${BOLD}$NAC_BYPASS_DIR${RESET}"
echo -e "${INFO_EMOJI} ${BLUE}To use it, follow these steps after reboot and connecting the devices:${RESET}"
echo -e "${STEP_EMOJI} ${MAGENTA}1. Connect the switch to eth0 (native LAN interface of RPi4).${RESET}"
echo -e "${STEP_EMOJI} ${MAGENTA}2. Connect victim (e.g. printer) to eth1 (external USB LAN adapter).${RESET}"
echo -e "${STEP_EMOJI} ${MAGENTA}3. Change directory to the nac_bypass tool:${RESET}"
echo -e "   ${MAGENTA}   cd ${BOLD}$NAC_BYPASS_DIR${RESET}"
echo -e "${STEP_EMOJI} ${MAGENTA}4. Start the NAC bypass (replace eth0 and eth1 with your actual interface names if different):${RESET}"
echo -e "   ${MAGENTA}   sudo ./nac_bypass_setup.sh -1 eth0 -2 eth1${RESET}"
echo -e "   ${INFO_EMOJI} ${BLUE}The script will prompt you to wait. After it completes, you can proceed with your network scan.${RESET}"
echo -e "   ${INFO_EMOJI} ${BLUE}Remember for Responder, you need to set it up to listen on the bridge interface (br0) and change the answering IP to the victim's IP:${RESET}"
echo -e "   ${MAGENTA}   ./Responder.py -I br0 -e victim.ip${RESET}"
echo -e "   ${INFO_EMOJI} ${BLUE}You can inspect iptables rules with: ${BOLD}iptables -t nat -L${RESET}\n"

echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
echo -e "${BOLD}${CYAN}SilentBridge Tool Information:${RESET}"
echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
echo -e "${INFO_EMOJI} ${BLUE}The 'silentbridge' tool has been installed in: ${BOLD}$SILENTBRIDGE_DIR${RESET}"
echo -e "${INFO_EMOJI} ${BLUE}To test run silentbridge, navigate to its directory and use the python2 virtual environment:${RESET}"
echo -e "   ${MAGENTA}   cd ${BOLD}$SILENTBRIDGE_DIR${RESET}"
echo -e "   ${MAGENTA}   source venv2/bin/activate${RESET}"
echo -e "   ${MAGENTA}   python2 ./silentbridge${RESET}"
echo -e "   ${MAGENTA}   deactivate${RESET}"
echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
