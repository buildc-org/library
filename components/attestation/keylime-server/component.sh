for component in registrar verifier; do
    cat > "/etc/keylime/${component}.conf.d/50-component-keylime-server.conf" << EOF
[${component}]
ip = "0.0.0.0"
EOF
    chown keylime:keylime "/etc/keylime/${component}.conf.d/50-component-keylime-server.conf"
    chmod 0400 "/etc/keylime/${component}.conf.d/50-component-keylime-server.conf"
done
