#!/usr/bin/perl

use warnings;
use strict;
use Net::Netmask;
use Template;

if ($#ARGV < 1){
    print "Usage: $0 dir country1 country2 ... countryN\n\n";
    exit 1;
}

my $pwd = $ARGV[0];

if (! -d $pwd){
    print STDERR "Directory $pwd doesn't exist, aborting.\n\n";
    exit 1;
}

shift @ARGV;

# Create list of country codes to get addresses for
my $countries;
$countries->{$_}++ foreach @ARGV;

# Create list of Maxmind geoname_ids to get addresses for
#geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,is_in_european_union
my @values;
my $country_code;
open my $fh, '<GeoLite2-Country-Locations-en.csv' or die "GeoLite2-Country-Locations-en.csv missing.\n";
<$fh>;

while (<$fh>){
    chomp;
    @values = split /,/;
    next unless ($countries->{$values[4]});
    $country_code->{$values[0]} = $values[4];
}
close $fh;

# Retrieve IPv4 address blocks for geoname_ids
#network,geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider
my @networks4;
open $fh, '<GeoLite2-Country-Blocks-IPv4.csv' or die "GeoLite2-Country-Blocks-IPv4.csv missing.\n";
<$fh>;

while (<$fh>){
    chomp;
    @values = split /,/;
    next unless ($country_code->{$values[1]});
    push @networks4, Net::Netmask->new($values[0]);
}
close $fh;

# Retrieve IPv6 address blocks for geoname_ids
my @networks6;
open $fh, '<GeoLite2-Country-Blocks-IPv6.csv' or die "GeoLite2-Country-Blocks-IPv6.csv missing.\n";
<$fh>;

while (<$fh>){
    chomp;
    @values = split /,/;
    next unless ($country_code->{$values[1]});
    push @networks6, Net::Netmask->new($values[0]);
}
close $fh;

# Produce templated nftables config
if (@networks4 or @networks6){

    my $tt = Template->new({
        INCLUDE_PATH => '/var/lib/maxmind'
    }) || die "$Template::ERROR\n";

    $tt->process('geoblock.conf.tt', {
        prefixes4 => [cidrs2cidrs(@networks4)],
        prefixes6 => [cidrs2cidrs(@networks6)],
    }) or die $tt->error();
}

__END__
