sed -i '/^INACTIVE=/d' /etc/default/useradd
echo 'INACTIVE=30' >> /etc/default/useradd
