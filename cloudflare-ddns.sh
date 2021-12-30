#!/bin/bash
# Cloudflare as Dynamic DNS
# Based on: https://github.com/nperanzi/cloudflare-ddns

# Script updated by Arno Pijnappels to make it possible to pass arguments to allow for scripting mulitple records
# usage cloudflare-ddns.sh -a APItoken -z ZoneID -h host.example.com -t <false/true>
# -a API Token needs to be created with CloudFlare with permissions: 1) Zone -> Zone -> Read 2) Zone -> DNS -> Edit
# -z Zone ID can be found from CloudFlare dashboard by opening your domain and scrolling down to the API section on the bottom right of the page (as of december 2021)
# -h host.example.com  The host record needs to be created upfront in the CloudFlare DNS settings. You can either create a CNAME or A record with a fake IP-address since the script will change it
# -t test run. Set to either false or true. Needs to be set to false in order for changes to be made to the CloudFlare DNS settings, any other setting than false will assume true
# -p proxied <true/false> Set either to true so CloudFlare hides your real IP or to false so the real IP is used (may be necessary for vpn access).
# -f force <true/false> Set to true to force update even if IP has not changed.

# Update these with real values or use arguments. Arguments override these settings
auth_token=""
zone_id=""
record_name=""
test_run="true"
proxy_realip="true"
force_update="false"

# Maximum number of lines in logfiles to keep
max_loglines=200000

while getopts a:z:h:t:p:f: opts; do
	case ${opts} in
		a) auth_token=${OPTARG} ;;
		z) zone_id=${OPTARG} ;;
		h) record_name=${OPTARG} ;;
		t) test_run=${OPTARG} ;;
		p) proxy_realip=${OPTARG} ;;
		f) force_update=${OPTARG} ;;
	esac
done

# If required settings are missing just exit
# Check API token
if [ "$auth_token" = "" ];  then
        echo "Missing API Token in -a flag, use as -a <API tokekn>."
        exit 2
fi

# Check Zone ID
if [ "$zone_id" = "" ];  then
        echo "Missing Zone ID in -z flag, use as -z <Zone ID>."
	exit 2
fi

# Check Record name
if [ "$record_name" = "" ]; then
        echo "Missing hostname in -h flag, you must specify which hostname to change. Use as -h <host.example.com>."
        exit 2
fi

# Check if test_run is set
if [ "$test_run" != "false" ];  then
	test_run="true"
        echo "Missing or invalid test_run argument => set to true so no changes will be made..."
fi

# Check if proxy_realip is set
if [ "$proxy_realip" != "false" ];  then
        proxy_realip="true"
        echo "Missing or invalid proxy_realip argument => set to true so real ip will be proxied by Cloudflare..."
fi

# Check if force_update is set
if [ "$force_update" != "true" ];  then
        force_update="false"
        echo "Missing or invalid force_update argument => set to false so no changes will be made if IP has not changed..."
fi



# Don't touch these
ip=$(curl -s http://ipv4.icanhazip.com)
ip_file="$record_name/cf-ddns_$record_name.ip"
id_file="$record_name/cf-ddns_$record_name.ids"
log_file="$record_name/cf-ddns_$record_name.log"


# Keep files in the same folder when run from cron
current="$(pwd)"
cd "$(dirname "$(readlink -f "$0")")"

# Use subfolder for log and other files
mkdir -p "$record_name"

log() {
	if [ "$1" ]; then
		echo -e "$(date "+%x %X")_$1" >> $log_file
	fi
}

echo "Check initiated..."
log "Check.."

if [ -f $ip_file ]; then
	old_ip=$(cat $ip_file)
	if [ $ip == $old_ip ]; then
		if [ $force_update == "true" ]; then
			echo "IP has not changed, force_update set to yes so force update of record"
			log "IP Unchanged -> force update"
		else
                        echo "IP has not changed, no changes will be made"
                        # Uncomment the next line to log when the IP remained the same
                        # log "IP Unchanged"
			exit 0
		fi
	fi
fi

if [ -f $id_file ] && [ $(wc -l $id_file | cut -d " " -f 1) == 2 ]; then
	zone_identifier=$zone_id
	record_identifier=$(head -1 $id_file)
else
	zone_identifier=$zone_id
	result=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" -H "Authorization: Bearer $auth_token" -H "Content-Type: application/json")
	stage=$(grep -Po '"id": *\K"[^"]*"' <<< $result)
	record_identifier=$(sed -e 's/^"//' -e 's/"$//' <<< "$stage")
	echo "$record_identifier" >> $id_file
fi

# Only change records when test_run argument equals false
if [ "$test_run" = "false" ]; then
	update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" -H "Authorization: Bearer $auth_token" -H "Content-Type: application/json" --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"proxied\":$proxy_realip,\"ttl\":1}")

	if [[ $update == *"\"success\":false"* ]]; then
		message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
		log "$message"
		echo -e "$message"
		exit 1 
	else
		message="DNS-record: $record_name changed to: $ip"
		echo "$ip" > $ip_file
		log "$message"
		echo "$message"
	fi
else
	echo "test_run != false so no records are changed"
fi

# Keep last max_loglines of logging
tail -n $max_loglines $log_file > $log_file.tmp
mv -f $log_file.tmp $log_file
