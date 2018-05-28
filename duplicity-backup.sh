#!/bin/bash

zabbix_server=$ZABBIX_SERVER
zabbix_key="backup.duplicity"
zabbix_key_duration="backup.duplicity.duration"
prometheus_pushgateway_url=$PROMETHEUS_PUSHGATEWAY_URL
prometheus_job=$PROMETHEUS_JOB
hostname=`hostname | cut -d\. -f1`
archive_dir="/var/lib/duplicity"
archive_name=${ARCHIVE_NAME:-$hostname}
url=$URL
backup_path="/host/$(echo $BACKUP_PATH | sed -e 's/^\///')"
influxdb_url=$INFLUXDB_URL
influxdb_dbname=$INFLUXDB_DBNAME
exclude_file="/duplicity-exclude.list"
full_if_older_than=${FULL_IF_OLDER_THAN:-1W}
remove_older_than=${REMOVE_OLDER_THAN:-2W}

trap cleanup INT TERM

function unlock {
	local lockfile="${archive_dir}/${archive_name}/lockfile.lock"
	if [ -e $lockfile ]; then
		rm -f $lockfile
	fi
}

function cleanup {
	write_log "INFO: signal catched, exiting"
	send_annotation interrupt
	unlock
	exit 1
}

function write_log {
	echo "`date +'%Y%m%d %H%M%S'`: $1"
}

function notify_zabbix {
	local key="$1"
	local value="$2"
	if [ -n "$zabbix_server" ]; then
		write_log "INFO: notify zabbix: $key: $value"
		zabbix_sender -z $zabbix_server -s $hostname -k $key -o $value 2>&1
	fi
}

function send_annotation {
	local state="$1"
	if [ -n "$influxdb_url" ]; then
		write_log "INFO: sending annotation: $state"
		curl -s -XPOST "${influxdb_url}/write?db=$influxdb_dbname" --data-binary 'annotations,host='$hostname' title="backup duplicity '$state'"'
	fi
}

function notify_prometheus {
	local success="$1"
	local duration="$2"
	if [ -n "$prometheus_pushgateway_url" ] && [ -n "$prometheus_job" ]; then
		write_log "INFO: notify prometheus: success: $success; duration: $duration"
		if [ "$success" -eq 1 ]; then
cat <<EOF | curl -s -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP batchjob_duration_seconds Duration of batch job
# TYPE batchjob_duration_seconds gauge
batchjob_duration_seconds $duration
# HELP batchjob_last_success Unixtime batch job last succeeded
# TYPE batchjob_last_success gauge
batchjob_last_success $(date +%s.%7N)
# HELP batchjob_success Success of batch job
# TYPE batchjob_success gauge
batchjob_success 1
EOF
		else
cat <<EOF | curl -s -XPOST --data-binary @- ${prometheus_pushgateway_url}/metrics/job/${prometheus_job}/instance/$hostname
# HELP batchjob_success Success of batch job
# TYPE batchjob_success gauge
batchjob_success 0
EOF
		fi
	fi
}

# MAIN

start_timastamp=`date +'%s'`
send_annotation start

write_log "INFO: duplicity start"
opts="--ssl-no-check-certificate --archive-dir=$archive_dir --name=$archive_name"

if [ -f "$exclude_file" ]; then
	write_log "INFO: use exclude list from file: $exclude_file"
	opts="$opts --exclude-filelist=$exclude_file"
fi 

exec 5>&1
output="`duplicity --full-if-older-than=$full_if_older_than $opts $backup_path $url 2>&1 | tee -a /dev/fd/5`"

if [ "`echo "$output" | grep -E '^Errors 0'`" ]; then
	write_log "INFO: duplicity remove old backups"
	duplicity remove-older-than $remove_older_than $opts --force $url 2>&1

	duration=$((`date +'%s'` - $start_timastamp))

	notify_zabbix $zabbix_key 1
	notify_zabbix $zabbix_key_duration $duration

	notify_prometheus 1 $duration

	write_log "INFO: duplicity stop, backup duration: $duration s"
else
	notify_zabbix $zabbix_key 0

	notify_prometheus 0

	write_log "ERROR: duplicity finished with errors"
fi

send_annotation stop
