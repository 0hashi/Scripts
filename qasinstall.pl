#!/usr/bin/perl
#
#	Paul Ohashi
#	One Identity
#	Jan '18
#
#	qasinstall.pl - Perl script that installs or removes Authentication Services client and
#	Group Policy client then joins the system to Active Directory. This script can also
#	create the Active Directory service principle account and keytab file.
#
#	NOTE: GRANT THE SERVICE PRINCIPLE ACCOUNT PERMISSIONS TO JOIN SYSTEMS TO ACTIVE DIRECTORY
#
#	The installation and removal are performed using an existing AD Service Principle and
#	Kerberos keytab file.
#
#	This script is provided "as is", without warranty or support of any kind. Permission is granted,
#	free of charge, to any person obtaining a copy of this script, to modify its contents without
#	restriction, merge, publish or distribute. Enjoy!
#
#	NOTE: Windows Service Principle name max 20 characters (including hostname-).
#
use strict;
use feature "switch";

#	NOTE: The value of $pasuMedia must exist in the $pasuMediaPath directory.
##### CONFIG
my $realm		= 'reddirt.lab';
my $domain		= 'reddirt.lab';
my $dcIPs		= '192.168.1.33 192.168.1.133';		# '1.2.3.4 1.2.3.5'
my $pasuMedia		= 'QAS_4_1_5_23233.tar.gz';
my $pasuMediaPath	= '/root/downloads/pasu/latestVersionOfQAS';
my $servicePrinciple	= 'ohashisan-joinunix';	# Prefix $servicePrinciple with "hostname-". Like: hostname-serviceprinciple
my $keytabFile		= './joinunix.keytab';
##### CONFIG
my $pasuSoftwareDir	= $pasuMedia;$pasuSoftwareDir =~ s/\..*$//g;
my ($licenseFile,$Administrator,$sAMAccountName,$dontDeleteDirs,$dontUnJoin,$extension);
my ($qasClientPkg,$vgpClientPkg);

my $underscore		= "_";
my $clientVersion	= $pasuMedia;
$clientVersion		=~ s/QAS_|\..*$//g;
$clientVersion          =~ s/_/\./g;
my ($majorV, $minorV, $bugFixRelease, $buildNumber)	= split(/\./, $clientVersion);
$clientVersion		= "$majorV.$minorV.$bugFixRelease-$buildNumber";

# Figure out what flavor of Linux
my $flavor		= `cat /proc/version`;
if ($flavor =~ "Ubuntu") {
	$flavor			= "ubuntu";
	$extension		= 'i386.deb';
	$qasClientPkg	= "$pasuMediaPath/$pasuSoftwareDir/client/linux-x86/vasclnt_${clientVersion}_${extension}";
	$vgpClientPkg	= "$pasuMediaPath/$pasuSoftwareDir/client/linux-x86/vasgp_${clientVersion}_${extension}";
}
elsif ($flavor =~ "Red Hat") {
	print "FLAVOR: $flavor\n";
}
else {
	print "qasinstall.pl can't find your operating system\n";
}


my $vastool		= '/opt/quest/bin/vastool';
my $DOMAIN		= $domain;$DOMAIN =~ s/\..*//g;
my $adContainer		= "CN=Computers,DC=${DOMAIN},DC=hq";
my $qasClient		= 'vasclnt';
my $vgpClient		= 'vasgp';
system("clear");

my $numArgs		= $#ARGV + 1;
if ($numArgs == 0) {
	usage();
	exit 1;
}
else
{
	if (! -d "$pasuMediaPath/$pasuSoftwareDir") {&gunZip();}
	my $theArg	= $ARGV[0];
	my $i	= 0;
	my ($j);
	given($theArg) {
		when (/^-h|--help$/i)    {&usage();exit 2;}
		when (/^-r|--remove/i)   {&remove($qasClient,$vgpClient);}
		when (/^-i|--install/i) {
			# Check for DN (-c)
			while (@ARGV) {
				if($ARGV[$i] =~ '-c') {$j = $i + 1;$adContainer="$ARGV[$j]";}
                		if($ARGV[$i] =~ '-l') {$j = $i + 1;$licenseFile="$ARGV[$j]";}
				last if($i == $numArgs -1);
				$i++;
			}
			# Install QAS and Group Policy clients
			system("dpkg -i $qasClientPkg;dpkg -i $vgpClientPkg");
			# Configure realm and create vas.conf
			system("$vastool configure realm $realm $dcIPs");
			# Join the system to AD
			#print "\n\nJOIN: $vastool -u $servicePrinciple -k $keytabFile join -f -c $adContainer -f $domain\n\n";
			system("$vastool -u $servicePrinciple -k $keytabFile join -f -c $adContainer -f $domain");
			if($licenseFile) {&addLicense();}
		}
		default	{print "\n\n";}
	}
	if($theArg =~ /-s|--service/) {
		while (@ARGV) {
                	if($ARGV[$i] =~ '-u') {$j = $i + 1;$Administrator="$ARGV[$j]";}
                	if($ARGV[$i] =~ '-a') {$j = $i + 1;$sAMAccountName="$ARGV[$j]";}
                	last if($i == $numArgs -1);
                	$i++;
                }
		if(!defined $Administrator or !defined $sAMAccountName) {&usage();exit 3;}
		# Install QAS and Group Policy clients
		system("dpkg -i $qasClientPkg;dpkg -i $vgpClientPkg");
		# Configure realm and create vas.conf
		system("$vastool configure realm $realm $dcIPs");
		# Create the AD Service Principle keytab file
		system("vastool -u $Administrator service create $sAMAccountName/$domain");
		system("mv /etc/opt/quest/vas/${sAMAccountName}.keytab .");
		#$dontDeleteDirs	= 'true';
		#$dontUnJoin	= 'true';
		#&remove($qasClient,$vgpClient,$dontDeleteDirs,$dontUnJoin);
	}
	# Add a license for Authentication Services
	if($theArg eq '-l') {
		$j = $i + 1;
		$licenseFile="$ARGV[$j]";
		while (@ARGV) {
                	if($ARGV[$i] =~ '-a') {$j = $i + 1;$Administrator="$ARGV[$j]";}
                	last if($i == $numArgs -1);
                	$i++;
                }
		&addLicense($Administrator,$licenseFile);
	}
}

sub gunZip($pasuMedia,$pasuMediaPath) {
	system("cd $pasuMediaPath;tar zxf $pasuMediaPath/$pasuMedia");
}

sub remove($qasClient,$vgpClient) {
	if($dontUnJoin ne 'true') {system("$vastool -u $servicePrinciple -k $keytabFile unjoin");}
	system("dpkg --purge $qasClient $vgpClient");
	if($dontDeleteDirs ne 'true') {system("rm -fr /opt/quest /etc/opt/quest /var/opt/quest");}
	exit;
}

sub addLicense() {
		system("$vastool license add $licenseFile >/dev/null 2>&1");
}

sub usage() {
print "\nUsage: qasinstall.pl [-r|--remove] [-i|--install] [-c container] [-h|--help]

-i|--install - Install Authentication Services and Group Policy Clients
	       and join system to Active Directory.

-c container - Use only with -i. Default container: CN=Computers,DC=DOMAIN,DC=com

-l|--license - Add/Update Authentication Services license

-r|--remove  - Remove Authentication Services and Group Policy packages
	       and delete PASU configuration directories.

-s	     - Create Service Principle account and Kerberos keytab file.

-h|--help    - Display this usage.

Example:

Install QAS:
		qasinstall.pl -i
		qasinstall.pl -i -l <license file>
		qasinstall.pl -i -c OU=Ubuntu,OU=Linux,OU=Servers,OU=AuthenticationSerices,DC=ohashisan,DC=hq
		qasinstall.pl -i -c OU=Ubuntu,OU=Linux,OU=Servers,OU=AuthenticationSerices,DC=ohashisan,DC=hq -l <license file>

Remove QAS:
		qasinstall.pl -r

Create Service Principle:
		qasinstall.pl -s -u <Administrator> -a <Service Principle>\n\n";
}
