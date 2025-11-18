#!/bin/sh

# Timestamp in the format expected by GlobalProtect server
NOW=$(date +'%m/%d/%Y %H:%M:%S')
DAY=$(date +'%d')
MONTH=$(date +'%m')
YEAR=$(date +'%Y')
MD5=

while [ "$1" ]; do
	if [ "$1" = "--cookie" ]; then
		shift
		COOKIE="$1"
	fi
	if [ "$1" = "--client-ip" ]; then
		shift
		IP="$1"
	fi
	if [ "$1" = "--client-ipv6" ]; then
		shift
		IPV6="$1"
	fi
	if [ "$1" = "--md5" ]; then
		shift
		MD5="$1"
	fi
	shift
done

USER=$(echo "$COOKIE" | sed -rn 's/(.+&|^)user=([^&]+)(&.+|$)/\2/p')
HOST_ID="deadbeef-dead-beef-dead-beefdeadbeef"

cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<hip-report>
	<md5-sum>$MD5</md5-sum>
	<user-name>$USER</user-name>
	<domain></domain>
	<host-name>ubuntu</host-name>
	<host-id>$HOST_ID</host-id>
	<ip-address>$IP</ip-address>
	<ipv6-address>$IPV6</ipv6-address>
	<generate-time>$NOW</generate-time>
	<hip-report-version>4</hip-report-version>
	<categories>
		<entry name="host-info">
			<client-version>6.2.1-12</client-version>
			<os>Linux Ubuntu 24.04.3 LTS</os>
			<os-vendor>Linux</os-vendor>
			<domain></domain>
			<host-name>ubuntu</host-name>
			<host-id>$HOST_ID</host-id>
			<network-interface>
				<entry name="enp0s3">
					<description>enp0s3</description>
					<mac-address>01-02-03-00-00-01</mac-address>
					<ip-address>
						<entry name="$IP"/>
					</ip-address>
					<ipv6-address>
						<entry name="$IPV6"/>
					</ipv6-address>
				</entry>
			</network-interface>
		</entry>
		<entry name="anti-malware">
			<list>
				<entry>
					<ProductInfo>
						<Prod vendor="Cisco Systems, Inc." name="ClamAV" version="1.0.5" defver="27818" engver="" datemon="$MONTH" dateday="$DAY" dateyear="$YEAR" prodType="3" osType="1"/>
						<real-time-protection>yes</real-time-protection>
						<last-full-scan-time>n/a</last-full-scan-time>
					</ProductInfo>
				</entry>
			</list>
		</entry>
		<entry name="disk-backup">
			<list>
			</list>
		</entry>
		<entry name="disk-encryption">
			<list>
			</list>
		</entry>
		<entry name="firewall">
			<list>
				<entry>
					<ProductInfo>
						<Prod vendor="IPTables" name="IPTables" version="1.8.10"/>
						<is-enabled>no</is-enabled>
					</ProductInfo>
				</entry>
				<entry>
					<ProductInfo>
						<Prod vendor="The Netfilter Project" name="nftables" version="1.0.9"/>
						<is-enabled>yes</is-enabled>
					</ProductInfo>
				</entry>
				<entry>
					<ProductInfo>
						<Prod vendor="Canonical Ltd." name="UFW" version="0.36.2"/>
						<is-enabled>no</is-enabled>
					</ProductInfo>
				</entry>
			</list>
		</entry>
		<entry name="patch-management">
			<list>
				<entry>
					<ProductInfo>
						<Prod vendor="GNU" name="Advanced Packaging Tool" version="2.8.3"/>
						<is-enabled>yes</is-enabled>
					</ProductInfo>
				</entry>
				<entry>
					<ProductInfo>
						<Prod vendor="Canonical Ltd." name="Snap" version="2.72"/>
						<is-enabled>yes</is-enabled>
					</ProductInfo>
				</entry>
			</list>
			<missing-patches></missing-patches>
		</entry>
		<entry name="data-loss-prevention">
			<list>
			</list>
		</entry>
	</categories>
</hip-report>
EOF
