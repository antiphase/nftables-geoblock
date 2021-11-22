1. Sign up for free Maxmind GeoLite 2 database account: https://dev.maxmind.com/geoip/geolite2-free-geolocation-data

2. Create maxmind user with /var/lib/maxmind as the home directory, and add the sudoers config to /etc/sudoers.d

3. Put geoblock.conf.tt and bin/ in /var/lib/maxmind and fix perms

4. Add cron job to run wrapper script each Wednesday as the maxmind user
