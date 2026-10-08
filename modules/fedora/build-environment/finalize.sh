if [ -e /usr/bin/systemctl.bak ]; then
    rm -f /usr/bin/systemctl
    mv /usr/bin/systemctl.bak /usr/bin/systemctl
fi
