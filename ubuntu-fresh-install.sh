#!/bin/bash

# Check if terminal supports colors
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
	CYAN='\033[1;36m'      # For progress updates	
	YELLOW='\033[1;33m'    # For warnings
	WHITE='\033[1;37m'     # For information
	GREEN='\033[1;32m'     # For success messages
	RED='\033[1;31m'       # For errors
	NC='\033[0m'           # No color (reset)
else
    # No colors if terminal doesn't support them
    CYAN=''
	YELLOW=''
	WHITE=''
	GREEN=''
	RED=''
	NC=''
fi

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}This script must be run as root. Please use sudo.${NC}"
	exit 1
fi

echo "Starting Ubuntu setup..."

update_system() {
	echo -e "${CYAN}Updating and upgrading package list...${NC}"
	if apt-get update && apt-get upgrade -y; then
		echo -e "${GREEN}Package list updated and upgraded successfully${NC}"
	else
		echo -e "${RED}Failed to update or upgrade packages${NC}"
	fi
}

install_essentials(){
	echo -e "${CYAN}Installing essential packages...${NC}"
	local PACKAGES=(
		neovim
		git
		gh
		curl
	)

	if apt-get install -y "${PACKAGES[@]}"; then
		echo -e "${GREEN}Essential packages installed successfully${NC}"
	else
		echo -e "${RED}Failed to install some essential packages${NC}"
	fi
}

install_snaps(){
	echo -e "${CYAN}Installing applications from the Snap Store...${NC}"	
	snap install --classic code
	#snap install spotify
	snap install discord
}

install_docker(){
	echo -e "${CYAN}Installing Docker Engine...${NC}"
	# 1. Set up Docker's apt repository.
	
	# Add Docker's official GPG key:
	apt-get update
	apt-get install -y ca-certificates curl
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
	  tee /etc/apt/sources.list.d/docker.list > /dev/null
	  apt-get update

	# 2. Install the Docker packages
	apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

configure_docker_permissions(){
    if [ -n "$SUDO_USER" ]; then
        echo -e "${CYAN}Adding user '$SUDO_USER' to the docker group...${NC}"
        usermod -aG docker "$SUDO_USER"
        echo -e "${CYAN}Configuring automatic GUI access for user '$SUDO_USER'...${NC}"
        
        local LINE_TO_ADD="xhost +local:"
        local USER_BASHRC="/home/$SUDO_USER/.bashrc"
        
        # Direct approach - no subshell needed
        if [[ -f "$USER_BASHRC" ]]; then
            if ! grep -Fxq "$LINE_TO_ADD" "$USER_BASHRC"; then
                echo "$LINE_TO_ADD" >> "$USER_BASHRC"
                echo -e "${GREEN}Added Docker X11 forwarding to .bashrc${NC}"
            else
                echo -e "${YELLOW}Docker X11 forwarding already configured${NC}"
            fi
            # Ensure proper ownership
            chown "$SUDO_USER:$SUDO_USER" "$USER_BASHRC"
        else
            echo -e "${YELLOW}Warning: .bashrc not found at $USER_BASHRC${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: Could not determine original user for Docker configuration.${NC}" 
    fi
}

update_system
install_essentials
install_docker
configure_docker_permissions
install_snaps

echo -e "${GREEN}All Done.${NC}"
echo -e "${WHITE}====================================================${NC}"
echo -e "${CYAN}IMPORTANT:${WHITE} Please reboot or log out and log back in${NC}"
echo -e "${WHITE}to apply Docker group permissions.${NC}"
echo -e "${WHITE}====================================================${NC}"