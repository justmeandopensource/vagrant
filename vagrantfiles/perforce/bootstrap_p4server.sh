#!/bin/bash

# Perforce admin user with no sudo privileges
readonly P4ADMIN_USER=p4adm
readonly P4BASE_DIR=/perforce

# Perforce binaries to download from Perforce ftp site
readonly P4BINARIES="p4d p4broker"

# P4D variables
readonly P4DPORT=1669
readonly P4DROOT=$P4BASE_DIR/root
readonly P4DLOG_DIR=$P4BASE_DIR/log
readonly P4DLOG_FILE=$P4DLOG_DIR/p4d.log
readonly P4DAUDITLOG_FILE=$P4DLOG_DIR/p4daudit.log
readonly P4DJOURNAL_DIR=$P4BASE_DIR/journal
readonly P4DJOURNAL_FILE=$P4DJOURNAL_DIR/journal
readonly P4D_SERVICE_FILE=/etc/systemd/system/p4d.service
readonly P4D_CONFIG_FILE=/etc/sysconfig/p4d

# P4BROKER variables
readonly P4BPORT=1666
readonly P4BROOT=$P4BASE_DIR/broker
readonly P4B_CONFIG_FILE=$P4BROOT/p4broker.conf
readonly P4B_LOG_FILE=$P4DLOG_DIR/p4broker.log
readonly P4B_SERVICE_FILE=/etc/systemd/system/p4broker.service

echo "[TASK 1] Downloading Perforce binaries $P4BINARIES"
for prog in $P4BINARIES
do
  wget -nd -q -m --ftp-user=anonymous --ftp-password=x ftp://ftp.perforce.com/perforce/r18.1/bin.linux26x86_64/$prog -O /usr/local/bin/$prog
  chmod +x /usr/local/bin/$prog
done

echo "[TASK 2] Creating Perforce directory structure"
mkdir $P4BASE_DIR $P4DROOT $P4DLOG_DIR $P4DJOURNAL_DIR $P4BROOT
chown -R $P4ADMIN_USER:$P4ADMIN_USER $P4BASE_DIR
chmod -R 750 $P4BASE_DIR

echo "[TASK 3] Creating p4d config file $P4D_CONFIG_FILE"
cat >> $P4D_CONFIG_FILE <<EOF
P4PORT=$P4DPORT
P4ROOT=$P4DROOT
P4JOURNAL=$P4DJOURNAL_FILE
P4LOG=$P4DLOG_FILE
P4AUDITLOG=$P4DAUDITLOG_FILE
P4USER=$P4ADMIN_USER
P4TICKETS=$P4BASE_DIR/.p4tickets
P4LOGLEVEL=3
EOF

echo "[TASK 4] Creating systemd unit file for p4d service"
cat >> $P4D_SERVICE_FILE <<EOF
[Unit]
Description=Perforce Server
After=network.target

[Service]
EnvironmentFile=/etc/sysconfig/p4d
Type=forking
User=$P4ADMIN_USER
ExecStart=/usr/local/bin/p4d -r \$P4ROOT -J \$P4JOURNAL -p \$P4PORT -L \$P4LOG -v server=\$P4LOGLEVEL -A \$P4AUDITLOG -d

[Install]
WantedBy=multi-user.target
EOF

echo "[TASK 5] Creating p4b config file $P4B_CONFIG_FILE"
cat >> $P4B_CONFIG_FILE <<EOF
target      = localhost:$P4DPORT;
listen      = $P4BPORT;
directory   = $P4BROOT;
logfile     = $P4B_LOG_FILE;
debug-level = server=3;
admin-name  = "Perforce Admin";
admin-phone = 12345;
admin-email = $P4ADMIN_USER@localhost;

compress    = false;
redirection = selective;
EOF

echo "[TASK 6] Creating systemd unit file for p4broker service"
cat >> $P4B_SERVICE_FILE <<EOF
[Unit]
Description=Perforce Broker Service
After=network.target

[Service]
Type=forking
User=$P4ADMIN_USER
ExecStart=/usr/local/bin/p4broker -c $P4B_CONFIG_FILE -d

[Install]
WantedBy=multi-user.target
EOF

echo "[TASK 7] Enabling p4d and p4broker service to start at boot"
systemctl enable p4d p4broker >/dev/null 2>/dev/null

echo "[TASK 8] Starting p4d and p4broker service"
systemctl start p4d p4broker

echo "[TASK 9] Initialize protection table with super access for $P4ADMIN_USER"
cat >>/tmp/protects <<EOF
Protections:
  write user * * //...
  super user p4adm * //...
  write user gconn-user * //...
EOF
su - $P4ADMIN_USER -c "cat /tmp/protects | p4 protect -i" > /dev/null 2>&1

echo "[TASK 10] Install Latest Git package"
yum install -y autoconf libcurl-devel expat-devel gcc gettext-devel kernel-headers openssl-devel perl-devel zlib-devel >/dev/null 2>&1
curl -s -O -L https://github.com/git/git/archive/v2.16.3.tar.gz
tar -zxf v2.16.3.tar.gz
cd git-2.16.3
make clean >/dev/null 2>&1
make configure >/dev/null 2>&1
./configure --prefix=/usr/local/git >/dev/null 2>&1
make >/dev/null 2>&1
make install >/dev/null 2>&1
cd ..
rm -rf git-2.16.3 v2.16.3.tar.gz
echo "pathmunge /usr/local/git/bin" > /etc/profile.d/git.sh

echo "[TASK 11] Set up Perforce Yum Repo for Git Connector"
cat >>/etc/yum.repos.d/Perforce.repo <<EOF
[perforce]
name=Perforce for CentOS $releasever - $basearch
baseurl=http://package.perforce.com/yum/rhel/7/x86_64/
enabled=1
gpgcheck=1
gpgkey=http://package.perforce.com/perforce.pubkey
EOF

echo "[TASK 12] Import Helix core server package signing key"
rpm --import http://package.perforce.com/perforce.pubkey > /dev/null 2>&1

echo "[TASK 13] Install Git Connector package"
yum install -y -q helix-git-connector > /dev/null 2>&1

echo "[TASK 14] Configure Git Connector"
/opt/perforce/git-connector/bin/configure-git-connector.sh -n\
   --p4port "localhost:$P4BPORT" \
   --super "$P4ADMIN_USER" \
   --superpassword "$P4ADMIN_USER" \
   --graphdepot "gitdepot" \
   --gcuserp4password "gconn-password" \
   --https \
   --gconnhost "p4server.example.com" \
   --forcehttps > /root/git-connector-install.log 2>&1
