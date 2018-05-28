#!/bin/bash

if [ -n "$TZ" ]; then
	apk add --no-cache tzdata
	if [ -f /usr/share/zoneinfo/$TZ ]; then
		cp /usr/share/zoneinfo/$TZ /etc/localtime
	echo "$TZ" >/etc/timezone
	fi
	apk del tzdata
fi

exec /duplicity-backup.sh
