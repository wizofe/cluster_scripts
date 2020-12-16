#!/bin/bash

set -e # exit on error
set -x # print command before doing it


# Options
ssh_server=true
pulseaudio=false
compilemonai=false
runvnc=false
virtualbox=false


# Set password hashes. Create with:
#   jupy: python -c "from notebook.auth import passwd; print(passwd())"
jupy_pw='argon2:$argon2id$v=19$m=10240,t=10,p=8$k9uoAnn3KFfJWO3SNMvYmQ$r8E9SnfzkkM4+SiQpIliJw'
vnc_pw='monai1'

# Mount our bash script
echo "source ~/bash_profile/rich_bashrc.sh" >> ~/.bashrc

# Colourful bash
echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\] '" >> ~/.bashrc

# Set git info
git config --global user.name "Richard Brown"
git config --global user.email "33289025+rijobro@users.noreply.github.com"

# Set paths
export PYTHONPATH="~/MONAI:~/ptproto:$PYTHONPATH"
export MONAI_DATA_DIRECTORY="/home/$(whoami)/data/MONAI"
printf "export PYTHONPATH=%s\n" "$PYTHONPATH" >> ~/.bashrc
printf "export MONA_DATA_DIRECTORY=%s\n" "$MONAI_DATA_DIRECTORY" >> ~/.bashrc
source ~/.bashrc

# Compile MONAI cuda code
if [ "$compilemonai" = true ]; then
	cd ~/MONAI
	BUILD_MONAI=1 python setup.py develop
fi

# SSH server
if [ "$ssh_server" = true ]; then
	nohup /usr/sbin/sshd -D -f ~/.ssh/sshd_config -E ~/sshd.log &
fi

# Pulseaudio (send audio back to local terminal)
if [ "$pulseaudio" = true ]; then
        apt update
	apt install -y pulseaudio espeak
	echo 'export PULSE_SERVER="tcp:localhost:24713"' >> ~/.bashrc
	pulseaudio --start
fi

# Start a VNC server
if [ "$runvnc" = true ] ; then
	apt update
	# switch commenting of next two lines for ubuntu instead of xfce4
	DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies
	# DEBIAN_FRONTEND=noninteractive apt install -y ubuntu-desktop
	apt install -y vnc4server

	mkdir -p ~/.vnc
	touch ~/.vnc/xstartup
	chmod +x ~/.vnc/xstartup

	# ubuntu or xfce4?
	echo "xfce4-session &" >> ~/.vnc/xstartup
	# echo "gnome-session &" >> ~/.vnc/xstartup

	# Start the vnc server (first time requires pw)
	printf "$vnc_pw\n$vnc_pw\n" | vncserver
fi

if [ "$virtualbox" = true ] ; then
	wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | apt-key add -
	wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | apt-key add -
	apt install -y software-properties-common
	add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"
	apt update
	apt install -y linux-headers-generic
	apt install -y virtualbox-6.1
	apt install -y virtualbox
fi

# Start jupyter
jupyter notebook --ip 0.0.0.0 --no-browser --allow-root --notebook-dir="~" --NotebookApp.password=${jupy_pw}

sleep infinity