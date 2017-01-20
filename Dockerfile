FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
	&& apt-get install -y wget curl python-pip librsync-dev rsync \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

ENV ZABBIX_AGENT_VERSION="3.2.0"
ENV ZABBIX_AGENT="zabbix_agents_${ZABBIX_AGENT_VERSION}.linux2_6_23.amd64"
RUN wget -qO /tmp/${ZABBIX_AGENT}.tar.gz http://www.zabbix.com/downloads/${ZABBIX_AGENT_VERSION}/${ZABBIX_AGENT}.tar.gz \
	&& mkdir /tmp/$ZABBIX_AGENT \
	&& tar xpzf /tmp/${ZABBIX_AGENT}.tar.gz -C /tmp/$ZABBIX_AGENT \
	&& cp /tmp/${ZABBIX_AGENT}/bin/zabbix_sender /usr/bin/zabbix_sender \
	&& rm -rf /tmp/${ZABBIX_AGENT}.tar.gz /tmp/${ZABBIX_AGENT}

ENV DUPLICITY_VERSION="0.7.10"
ENV DUPLICITY="duplicity-$DUPLICITY_VERSION"
RUN wget -qO /tmp/${DUPLICITY}.tar.gz https://code.launchpad.net/duplicity/0.7-series/${DUPLICITY_VERSION}/+download/${DUPLICITY}.tar.gz \
	&& pip install /tmp/${DUPLICITY}.tar.gz boto urllib3 \
	&& rm /tmp/${DUPLICITY}.tar.gz

COPY duplicity-backup.sh /duplicity-backup.sh
RUN chmod +x /duplicity-backup.sh

CMD ["/duplicity-backup.sh"]
