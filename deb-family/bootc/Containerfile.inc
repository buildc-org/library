LABEL containers.bootc=1
CMD ["/sbin/init"]

RUN rm -rf /var/cache/* /var/log/*

COPY --from=ctx @MODULE@/hostname /etc/hostname
