#!/bin/bash

# === CONFIGURATION ===
NEW_SSH_PORT=9510 
UNPRIV_USER="debian"
SSH_KEY_PATH="/home/$UNPRIV_USER/.ssh/authorized_keys"
CURRENT_PORT=22


# Here we try using ssh config file for manage it 
SERVERS=( 
prom-grafana-arvantest
	)


for HOST in "${SERVERS[@]}"; do
    echo "------ Connecting to $HOST ------"

    ssh -p $CURRENT_PORT $UNPRIV_USER@$HOST bash -s <<EOF
# Backup sshd_config
cp /etc/ssh/sshd_config ~/sshd_config.bak

# Change SSH Port
if grep -q "^#Port" /etc/ssh/sshd_config; then
    sudo sed -i "s/^#Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
elif grep -q "^Port" /etc/ssh/sshd_config; then
    sudo sed -i "s/^Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
else
    echo "Port $NEW_SSH_PORT" >> /etc/ssh/sshd_config
fi

#Change root access
if grep -q "^#PermitRootLogin" /etc/ssh/sshd_config; then
    sudo sed -i "s/^#PermitRootLogin .*/PermitRootLogin yes/" /etc/ssh/sshd_config
elif grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sudo sed -i "s/^PermitRootLogin .*/PermitRootLogin yes/" /etc/ssh/sshd_config
else
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi

# Allow the new port through the firewall
if command -v ufw &> /dev/null; then
    ufw allow $NEW_SSH_PORT/tcp
    ufw reload
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=$NEW_SSH_PORT/tcp
    firewall-cmd --reload
fi

# Append the unprivileged user's authorized_keys to root
if [ -f "$SSH_KEY_PATH" ]; then
    # sudo mkdir -p /root/.ssh
    sudo cp "$SSH_KEY_PATH"  /root/.ssh/authorized_keys
    # sudo chmod 600 /root/.ssh/authorized_keys
    echo "Added $UNPRIV_USER's key to root authorized_keys."
else
    echo "ERROR: Public key file not found: $SSH_KEY_PATH"
fi
# Copy bashrc unprivileged user to root
if [ -f "/home/$UNPRIV_USER/.bashrc" ]; then
    sudo cp /home/$UNPRIV_USER/.bashrc /root/
    echo "Copied $UNPRIV_USER's .bashrc to root."
else
    echo "ERROR: .bashrc file not found for user $UNPRIV_USER"
fi
# Disable root login via password
sudo sed -i "s/^PermitRootLogin yes/PermitRootLogin without-password/" /etc/ssh/sshd_config
# Disable password authentication
sudo sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
# Restart SSH
sudo systemctl restart sshd ||sudo  service ssh restart

echo "[✔] $HOST: SSH port changed to $NEW_SSH_PORT"

EOF
    echo "------ Done with $HOST ------"
    echo
done
