#!/usr/bin/perl
#
# Paul Ohashi
# One Identity
#
# sasUsersAllowed.pl - Located in AuthenticationServicesDefault GPO -> Refresh Scripts.
#
# 8-20-21 modified to use a specific naming convention for Linux system hostnames and
# AD Groups names (%ComputerName%_ADMIN$ and %ComputerName%_READONLY$).
#
# 9-20-21 Added array for possible domain AD Groups (@adGroupsAllowed) to be added to the
# users.allow file and a foreach loop to test if any of the AD Groups in the array already
# exist.
#
# Zurich hostname naming convention: hostname.zurich.com
# AD Group Name naming convention: HOSTNAME_ADMIN$

use strict;

# Add AD Group names to the array below:
my $domain              = "GITDIR";
my @adGroupsAllowed     = ('_Admin$', '_ReadOnly$', '_Test$');

system('clear');
my $usersAllow          = '/etc/opt/quest/vas/users.allow';

if (! -f $usersAllow) {
        system("touch $usersAllow");
}

my $hostNameFQDN                = `hostname`;
my ($hostName, $Domain, $com)   = split(/\./, $hostNameFQDN);
chomp $hostName;

my $doesAdGroupExist;
foreach my $adGroupName (@adGroupsAllowed) {
        my $adGroupNameGrep     = $adGroupName;
           $adGroupNameGrep     =~ s/\$$/\\\$/g;

        #print "Grep string: ${domain}\\\\${hostName}${adGroupNameGrep}\n\n";

        $doesAdGroupExist       = `grep  \'${domain}\\\\${hostName}${adGroupNameGrep}\' $usersAllow`;
        chomp $doesAdGroupExist;
        #print "doesAdGroupExist: ($doesAdGroupExist)\n\n";

        #print "grep  \'${domain}\\\\${hostName}${adGroupNameGrep}\' $usersAllow\n\n";
        #print "AD Group: ${domain}\\${hostName}${adGroupName}\n";

    if (defined $doesAdGroupExist && length $doesAdGroupExist > 0) {
        my $x;
    } else {
        open (UA, ">>$usersAllow");
        print UA "${domain}\\${hostName}${adGroupName}\n";
        close UA;
    }
}
