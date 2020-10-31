# Variables section

dns_servers="8.8.8.8,8.8.4.4"
admin_password="passw0rd"

# pws
pwd=$(pwd)

# install depndencys
sudo dnf install epel-release -y
sudo dnf install git gcc gcc-c++ ansible nodejs gettext device-mapper-persistent-data lvm2 bzip2 python3-pip -y
sudo dnf install langpacks-en glibc-all-langpacks -y
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

#install docker
docker_ver=$(dnf list docker-ce  --showduplicates | grep docker-ce. | awk '{print $2}')
sudo dnf install docker-ce-$docker_ver -y

# Start docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
sudo pip3 install docker-compose

# switch to python 3
alternatives --set python /usr/bin/python3

# clone AWX
echo "clone awx"
[ ! -f $pwd/awx ] && git clone https://github.com/ansible/awx.git -q

# Config inventory 
if [ -f $pwd/awx/installer/conf_done ]; then
    echo "skipping inventory confg"
else
    secret_key=$(openssl rand -base64 30)

    sudo sed -i "/secret_key=/c\secret_key=$secret_key" awx/installer/inventory 
    sudo sed -i "/awx_alternate_dns_servers=/c\awx_alternate_dns_servers=$dns_servers" awx/installer/inventory 
    sudo sed -i "/admin_password=/c\admin_password=$admin_password" awx/installer/inventory 

    touch $pwd/awx/installer/conf_done
fi

[ ! -f /var/lib/pgdocker ] && sudo mkdir /var/lib/pgdocker

# Start AWX install
ansible-playbook -i $pwd/awx/installer/inventory $pwd/awx/installer/install.yml


if [[ ! $(sudo firewall-cmd --list-all | grep services) = *http* ]]; then
    sudo firewall-cmd --zone=public --add-masquerade --permanent
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
fi

# Disabel Selinux
sudo sed -i "/SELINUX=enforcing/c\SELINUX=disabled" /etc/sysconfig/selinux 
