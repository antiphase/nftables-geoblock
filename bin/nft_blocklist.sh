#!/bin/bash

set -ue
exec >/dev/null

# Arguments are a space-separated list of country codes we want to block
countries="$@"

if [[ -z "${countries}" ]]; then
    exit 1
fi

# See https://dev.maxmind.com/geoip/geoip2/geolite2/

if [[ ! -e /etc/GeoIP.conf ]]; then
    echo >&2 'Maxmind license key not found'
    exit 1
fi

tmpdir=$(mktemp -d)

pushd ${tmpdir}


########################################################################
# Retrieve latest free GeoLite Country database

license_key=$(awk '/^LicenseKey/{print $2}' /etc/GeoIP.conf | tr -d '\n')

if ! curl -sq "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=${license_key}&suffix=zip" > GeoLite2-Country-CSV.zip; then
    echo >&2 'Maxmind database retrieval failed'
    exit 1
fi

unzip -j -u GeoLite2-Country-CSV.zip '*/GeoLite2-Country-Locations-en.csv' '*/GeoLite2-Country-Blocks-IPv4.csv' '*/GeoLite2-Country-Blocks-IPv6.csv'

# Produce nftables config with drop prefix list
/var/lib/maxmind/bin/process_geoip.pl $PWD $countries > geoblock.conf

# Install file and reload nftables
/usr/bin/sudo /bin/chown root.root geoblock.conf
/usr/bin/sudo /bin/chmod 0644 geoblock.conf
/usr/bin/sudo /bin/cp geoblock.conf /etc/nftables.d
/usr/bin/sudo /bin/systemctl restart nftables

# Archive results
popd

if [[ ! -d /var/lib/maxmind/archive ]]; then
    mkdir -p /var/lib/maxmind/archive
fi

find /var/lib/maxmind/archive -type f -name '*.bz2' -mtime +365 -delete
tar -jcf /var/lib/maxmind/archive/geoip_work-$(date +%Y%m%d).tar.bz2 ${tmpdir}
rm -rf ${tmpdir}

exit 0
