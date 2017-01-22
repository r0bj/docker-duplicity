#!/bin/bash

if [ -n "$TZ" ] && [ -e /usr/share/zoneinfo/$TZ ]; then
	echo "$TZ" > /etc/timezone
	dpkg-reconfigure -f noninteractive tzdata
fi

exec /duplicity-backup.sh
