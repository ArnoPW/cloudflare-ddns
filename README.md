# cloudflare-ddns
Update a cloudflare DNS record to your WAN IP address using an API token

A bash script to update Cloudflare DNS records to the public IP of the machine executing the script.
This script uses a restricted API token instead of the global API key used in many other scripts.

## usage
1. Place the `cloudflare-ddns.sh` script on your linux machine
2. Make the script executable: `chmod +x cloudflare-ddns.sh`
3. Either change the variables in the script or call the script with arguments or a combination of these
4. Test the script
5. Create a cron-job to automatically execute the script on regular intervals\
The following syntax will run the script using arguments every 5 minutes:\
~~~
*/5 * * * * /bin/bash /opt/cloudflare-ddns/cloudflare-ddns.sh -a APIToken -z ZoneId -h host.example.com -t false
~~~

## variables
The following variables are used and can be 'hardcoded' in the script and/or set with arguments when executing the script. Variables passed as arguments will override values 'hardcoded'in the script.
* `auth_token` the API Token created at your Cloudflare account. Can be set as an argument as `-a APIToken`
* `zone_id` the Zone Id that Cloudflares assigned to your zone (example.com). Can be set as an argument as `-z ZoneId`
* `record_name` the actual DNS-record you want to set (host.example.com). Can be set as an argument as `-h RecordName`
* `test_run` if set to false record can be updated, any other value assumes a test run. Can be set as an argument as `-t false`. If not set the script assumes true.
* `proxy_realip` set to true so Cloudflare proxies your real IP. Set to false to use your real IP. Can be set as an argument as `-p true`. If not set the script assumes true.
* `force_update` set to true to force an update of the record even if your IP has not changed. Useful if you want to change `proxy_realip`. Can be set as an argument as `-f false`. If not set the script assumes false.

## control size of logfile
This script will log at least 1 line every time it is executed. If the IP-address is unchanged, then only be 1 line might be added unless `force_update` is set to `true` in which case 3 lines will be logged. When the IP-address changes 2 lines will be added to the log when the script is executed.
The script has a max_loglines variable that can be set to your preference. When the script is executed every 5 minutes with `force_update` set to `true`, approximately 3 x 12 x 60 = 2160 lines will be added every day.
If you don't want the logfiles to rotate then comment the last 2 lines of the script out like this:
~~~
# Keep last max_loglines of logging
# tail -n $max_loglines $log_file > $log_file.tmp
# mv -f $log_file.tmp $log_file
~~~
When rotating the logfiles, a temporary file is created containing the number of lines you would like to keep. This proces will temporarily need about the same disk space as the original file. When the temporary file is ready, it will overwrite the original file and free up the additional space used.
