#!/bin/bash

set -eu

if [[ $(id -u) == 0 ]]; then
    if [ -z "$1" ]; then
        echo "As root user you can run this script to create a new user './new-ubuntu-setup.sh <user>'"
        exit 1
    fi

    if id "$1" &>/dev/null; then
        echo "User $1 already exists"
        echo "Do NOT run this script as root!" 
        echo "If logged in as root, switch to $1 with 'su - $1'"
    else
        adduser $1 --gecos ""
        adduser $1 sudo
        echo "Created the user $1 and added to sudo group"

        sudo -u $1 mkdir /home/$1/.ssh
        sudo -u $1 cp /root/.ssh/authorized_keys /home/$1/.ssh
        echo "Copied authorized_keys to new user"

        sudo -u $1 mkdir -p /home/$1/projects
        mv /root/p-scripts /home/$1/projects
        chown -R $1:$1 /home/$1/projects/p-scripts
        echo "Moved p-scripts to /home/$1/projects"

        echo "To continue please switch to new user $1 with 'su - $1' first"
    fi

    echo "Then use 'sudo -u <username> <path to this script>/new-ubuntu-setup.sh'"
    exit 1
fi

echo "########################################"
echo "Update and upgrade packages"
echo "########################################"
sudo apt update && sudo apt upgrade -y

echo "########################################"
echo "Securing SSH"
echo "########################################"
echo "..."
sudo sed -i 's/#*PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#*PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/#*ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

sudo service sshd restart

echo "########################################"
echo "Installing fail2ban"
echo "########################################"
sudo apt install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

echo "########################################"
echo "Enabling firewall (ufw)"
echo "########################################"
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable

echo "########################################"
echo "Docker Installation"
echo "########################################"
while true
do
  read -p "Do you want to install Docker? [y/n] " answer

  case $answer in
   [yY]* )  sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release -y
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io -y
            echo "Installing docker compose v2"
            mkdir -p ~/.docker/cli-plugins/
            curl -SL https://github.com/docker/compose-cli/releases/download/v2.0.0-rc.2/docker-compose-linux-amd64 -o ~/.docker/cli-plugins/docker-compose
            chmod +x ~/.docker/cli-plugins/docker-compose
            sudo mkdir -p /root/.docker/cli-plugins/
            sudo cp ~/.docker/cli-plugins/docker-compose /root/.docker/cli-plugins/
            break;;

   [nN]* )  break;;

   * )      echo "Please enter either Y or N, please.";;
  esac
done

echo "########################################"
echo "Configuring git"
echo "########################################"
echo "..."
git config --global user.name "Polo Ma"
git config --global user.email "42830316+pma9@users.noreply.github.com"
git config --global init.defaultBranch main

echo "########################################"
echo "Checking for existing ssh key pair"
echo "########################################"
echo "..."
if [ ! -f $HOME/.ssh/id_ed25519.pub ]; then
    echo "Creating new ssh key-pair"
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
fi
echo "Copy the following key to Github: "
echo " "
cat $HOME/.ssh/id_ed25519.pub
echo " "
read -p "After adding the ssh key to Github, press enter"

# Verify that ssh has been added
ssh -T git@github.com || GIT_AUTHED=$?
if [ $GIT_AUTHED -ne 1 ]; then
    echo "Did you add your ssh key to Github?"
    exit 1
fi

echo "########################################"
echo "Installing ZSH"
echo "########################################"
if ! command -v zsh &> /dev/null; then
    sudo apt install zsh -y

    echo "Changing default shell to ZSH"
    chsh -s $(which zsh)
else
    echo "ZSH is already installed"
fi

echo "########################################"
echo "Installing Oh My ZSH"
echo "########################################"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My ZSH already installed"
fi

mkdir $HOME/.oh-my-zsh-custom
export ZSH_CUSTOM=$HOME/.oh-my-zsh-custom

echo "########################################"
echo "Installing powerlevel10k"
echo "########################################"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

echo "########################################"
echo "Installing JetBrainsMono Nerd Font"
echo "########################################"
git clone --depth=1 https://github.com/ryanoasis/nerd-fonts $HOME/setup_tmp/nerd-fonts
trap "rm -rf $HOME/setup_tmp" EXIT
$HOME/setup_tmp/nerd-fonts/install.sh JetBrainsMono

echo "########################################"
echo "Installing custom Oh My ZSH plugins"
echo "########################################"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

echo "########################################"
echo "Setting up pma9/my-config"
echo "########################################"
git clone --bare git@github.com:pma9/my-config.git $HOME/.my-config
function myconfig {
   /usr/bin/git --git-dir=$HOME/.my-config/ --work-tree=$HOME $@
}
myconfig checkout && status=0 || status=1
if [ $status = 0 ]; then
    echo "Checked out my-config";
else
    echo "Backing up pre-existing dot files."
    mkdir -p $HOME/.my-config-backup
    # Prefix $HOME not tested yet
    myconfig checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} $HOME/.my-config-backup/{}
    myconfig checkout
fi;
myconfig config --local status.showUntrackedFiles no

echo "########################################"
echo "Cleaning up"
echo "########################################"
sudo rm -rf $HOME/setup_tmp

echo "########################################"
echo "Setup Finished Successfully!"
echo "########################################"
