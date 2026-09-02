LABEL containers.bootc=1
CMD ["/sbin/init"]

RUN rm -rf /var/cache/* /var/log/*

COPY <<EOF /etc/hostname
EOF
