#!/bin/bash

set -eu

danger_print() {
    printf "\e[31m$1\e[0m\n"
}

success_print() {
    printf "\e[32m$1\e[0m\n"
}

info_print() {
    printf "\e[33m$1\e[0m\n"
}

header_print() {
    printf "\n########################################\n"
    printf "$1\n"
    printf "########################################\n\n"
}

########################################
# User Creation
########################################
if [[ $(id -u) == 0 ]]; then
    if [ -z "$1" ]; then
        info_print "As root user you can run this script to create a new user './ubuntu-server-setup.sh <user>'"
        exit 1
    fi

    if id "$1" &>/dev/null; then
        success_print "User $1 already exists"
        danger_print "Do NOT run this script as root!" 
        danger_print "If logged in as root, switch to $1 with 'su - $1'"
    else
        adduser $1 --gecos ""
        adduser $1 sudo
        success_print "Created the user $1 and added to sudo group"

        sudo -u $1 mkdir /home/$1/.ssh
        sudo -u $1 cp /root/.ssh/authorized_keys /home/$1/.ssh
        success_print "Copied authorized_keys to new user"

        sudo -u $1 mkdir -p /home/$1/projects
        mv /root/p-scripts /home/$1/projects
        chown -R $1:$1 /home/$1/projects/p-scripts
        success_print "Moved p-scripts to /home/$1/projects"

        info_print "To continue please switch to new user $1 with 'su - $1' first"
    fi

    info_print "Then use 'sudo -u <username> <path to this script>/ubuntu-server-setup.sh'"
    exit 1
fi

########################################
# Update & Upgrade
########################################
header_print "Update and upgrade packages"
sudo apt update && sudo apt upgrade -y

########################################
# SSHD Configuration
########################################
header_print "SSHD Configuration"

sudo sed -i 's/#*PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#*PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/#*ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

info_print "Restarting sshd service"
sudo service sshd restart

success_print "Configured sshd_config file and restarted the sshd service"

########################################
# SSH Key Pair
########################################
info_print "Checking for existing ssh key pair"

if [ ! -f $HOME/.ssh/id_ed25519.pub ]; then
    info_print "SSH key pair (ed25519) does not exist ..."
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
    success_print "Created new ssh key-pair (ed25519)"
else 
    success_print "SSH key pair exists"
fi

info_print "Copy the following key to Github: "
printf "\n"
cat $HOME/.ssh/id_ed25519.pub
printf "\n"

read -p $'\e[33mAfter adding the ssh key to Github, press enter\e[0m\n'

# Verify that ssh has been added
ssh -T git@github.com || GIT_AUTHED=$?
if [ $GIT_AUTHED -ne 1 ]; then
    danger_print "Did you add your ssh key to Github?"
    exit 1
fi

########################################
# Fail2ban
########################################
header_print "Fail2ban Installation"

sudo apt install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

success_print "Installed fail2ban and copied jail.conf"

########################################
# Firewall (ufw)
########################################
header_print "Configure and enable firewall (ufw)"

sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable

success_print "Enabled ufw with ssh, http and https rules"

########################################
# Docker
########################################
header_print "Docker Installation"

if ! command -v zsh &> /dev/null; then
    while true
    do
    read -p "Do you want to install Docker? [y/n] " answer

    case $answer in
    [yY]* )  sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release -y
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io -y
                info_print "Installing docker compose v2"
                mkdir -p ~/.docker/cli-plugins/
                curl -SL https://github.com/docker/compose-cli/releases/download/v2.0.0-rc.2/docker-compose-linux-amd64 -o ~/.docker/cli-plugins/docker-compose
                chmod +x ~/.docker/cli-plugins/docker-compose
                sudo mkdir -p /root/.docker/cli-plugins/
                sudo cp ~/.docker/cli-plugins/docker-compose /root/.docker/cli-plugins/
                success_print "Installed Docker"
                break;;

    [nN]* )  break;;

    * )      info_print "Please enter either Y or N, please.";;
    esac
    done
else
    success_print "Docker is already installed"
fi

########################################
# GIT
########################################
header_print "Git Configuration"

git config --global user.name "Polo Ma"
git config --global user.email "42830316+pma9@users.noreply.github.com"
git config --global init.defaultBranch main

success_print "Successfully configured git"

########################################
# ZSH
########################################
header_print "ZSH Installation"

if ! command -v zsh &> /dev/null; then
    sudo apt install zsh -y
    success_print "Successfully installed ZSH"

    info_print "Changing default shell to ZSH:"
    chsh -s $(which zsh)
else
    success_print "ZSH is already installed"
fi

########################################
# Oh My ZSH
########################################
header_print "Oh My ZSH Installation"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    success_print "Successfully installed Oh My ZSH"
else
    success_print "Oh My ZSH already installed"
fi

mkdir $HOME/.oh-my-zsh-custom
export ZSH_CUSTOM=$HOME/.oh-my-zsh-custom

success_print "Created custom .oh-my-zsh-custom directory"

########################################
# PowerLevel10k
########################################
header_print "PowerLevel10K Theme"

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
success_print "Successfully downloaded PowerLevel10K theme"

########################################
# JetBrainsMono Nerd Font
########################################
header_print "JetBrainsMono Nerd Font Installation"

git clone --depth=1 https://github.com/ryanoasis/nerd-fonts $HOME/setup_tmp/nerd-fonts
trap "rm -rf $HOME/setup_tmp" EXIT
$HOME/setup_tmp/nerd-fonts/install.sh JetBrainsMono
success_print "Successfully installed JetBrainsMono Nerd Font"

########################################
# Oh My ZSH plugins
########################################
header_print "Oh My ZSH plugins"

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
success_print "Successfully downloaded zsh-autosuggestions"

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
success_print "Successfully downloaded zsh-syntax-highlighting"

########################################
# pma9/my-config
########################################
header_print "Setting up my-config"

git clone --bare git@github.com:pma9/my-config.git $HOME/.my-config
function myconfig {
   /usr/bin/git --git-dir=$HOME/.my-config/ --work-tree=$HOME $@
}
myconfig checkout && status=0 || status=1
if [ $status = 0 ]; then
    success_print "Setup my-config and checked it out";
else
    info_print "Backing up pre-existing dot files."
    mkdir -p $HOME/.my-config-backup
    myconfig checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} $HOME/.my-config-backup/{}
    myconfig checkout
    success_print "Setup my-config and checked it out";
fi;
myconfig config --local status.showUntrackedFiles no

########################################
success_print "Setup Finished!!! 🎉\n"
########################################
