case "${OPT_REGISTRAR}" in
    '' | *[!A-Za-z0-9.:-]*)
        echo "keylime-agent: registrar must be a hostname or an IP address, got '${OPT_REGISTRAR}'" >&2
        exit 1
        ;;
esac

cat > /etc/keylime/agent.conf.d/50-component-keylime-agent.conf << EOF
[agent]
uuid = "hash_ek"
ip = "0.0.0.0"
registrar_ip = "${OPT_REGISTRAR}"
registrar_tls_enabled = false
EOF

chown keylime:keylime /etc/keylime/agent.conf.d/50-component-keylime-agent.conf
chmod 0400 /etc/keylime/agent.conf.d/50-component-keylime-agent.conf
