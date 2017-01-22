#!/bin/bash

if [ -n "$TZ" ] && [ -e /usr/share/zoneinfo/$TZ ]; then
	ln -fs /usr/share/zoneinfo/$TZ /etc/localtime
	dpkg-reconfigure -f noninteractive tzdata 2>/dev/null
fi

exec /duplicity-backup.sh
