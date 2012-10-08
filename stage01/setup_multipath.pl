#!/usr/bin/perl
#use strict;
use Cwd;

$ENV{'PWD'} = getcwd();

# does_It_Have( $arg1, $arg2 )
# does the string $arg1 have $arg2 in it ??
sub does_It_Have{
	my ($string, $target) = @_;
	if( $string =~ /$target/ ){
		return 1;
	};
	return 0;
};



#################### APP SPECIFIC PACKAGES INSTALLATION ##########################

my @ip_lst;
my @distro_lst;
my @source_lst;
my @roll_lst;

my %cc_lst;
my %sc_lst;
my %nc_lst;

my $clc_index = -1;
my $cc_index = -1;
my $sc_index = -1;
my $ws_index = -1;

my $clc_ip = "";
my $cc_ip = "";
my $sc_ip = "";
my $ws_ip = "";

my $nc_ip = "";

my $rev_no = 0;

my $max_cc_num = 0;

$ENV{'EUCALYPTUS'} = "/opt/eucalyptus";

#### read the input list
print "\n";
print "Reading the Input File\n";
print "\n";

my $index = 0;

open( LIST, "../input/2b_tested.lst" ) or die "$!";

my $is_memo = 0;
my $memo = "";

my $line;
while( $line = <LIST> ){
	chomp($line);

	if( $is_memo ){
		if( $line ne "END_MEMO" ){
			$memo .= $line . "\n";
		}else{
			$is_memo = 0;
		};
	}elsif( $line =~ /^([\d\.]+)\s+(.+)\s+(.+)\s+(\d+)\s+(.+)\s+\[([\w\s\d]+)\]/ ){
		print "IP $1 with $2 distro is built from $5 as Eucalyptus-$6\n";
		push( @ip_lst, $1 );
		push( @distro_lst, $2 );
		push( @source_lst, $5 );
		push( @roll_lst, $6 );

		my $this_roll = $6;

		if( does_It_Have($this_roll, "CLC") && $clc_ip eq "" ){
			$clc_index = $index;
			$clc_ip = $1;
		};

		if( does_It_Have($this_roll, "CC") ){
			$cc_index = $index;
			$cc_ip = $1;

			if( $this_roll =~ /CC(\d+)/ ){
				$cc_lst{"CC_$1"} = $cc_ip;
				if( $1 > $max_cc_num ){
					$max_cc_num = $1;
				};
			};			
		};

		if( does_It_Have($this_roll, "SC") ){
			$sc_index = $index;
			$sc_ip = $1;

			if( $this_roll =~ /SC(\d+)/ ){
                                $sc_lst{"SC_$1"} = $sc_ip;
                        };
		};

		if( does_It_Have($this_roll, "WS") ){
                        $ws_index = $index;
                        $ws_ip = $1;
                };

		if( does_It_Have($this_roll, "NC") ){
                        #$nc_ip = $nc_ip . " " . $1;
			$nc_ip = $1;
			if( $this_roll =~ /NC(\d+)/ ){
				if( $nc_lst{"NC_$1"} eq	 "" ){
                                	$nc_lst{"NC_$1"} = $nc_ip;
				}else{
					$nc_lst{"NC_$1"} = $nc_lst{"NC_$1"} . " " . $nc_ip;
				};
                        };
                };


		$index++;
        }elsif( $line =~ /^BZR_REVISION\s+(\d+)/  ){
		$rev_no = $1;
		print "REVISION NUMBER is $rev_no\n";
	}elsif( $line =~ /^BZR_BRANCH\s+(.+)/ ){
			my $temp = $1;
			if( $temp =~ /eucalyptus\/(.+)/ ){
				$ENV{'QA_BZR_DIR'} = $1; 
			};
	}elsif( $line =~ /^TEST_NAME\s+(.+)/ ){
			print "\nTEST_NAME\t$1\n";
			$ENV{'QA_TEST_NAME'} = $1;
	}elsif( $line =~ /^UNIQUE_ID\s+(\d+)/ ){
			print "\nUNIQUE_ID\t$1\n";
			$ENV{'QA_UNIQUE_ID'} = $1;
	}elsif( $line =~ /^MEMO/ ){
		$is_memo = 1;
	}elsif( $line =~ /^END_MEMO/ ){
		$is_memo = 0;
	};
};

close( LIST );

$ENV{'QA_MEMO'} = $memo;

print "\n";

if( $source_lst[0] eq "PACKAGE" || $source_lst[0] eq "REPO" ){
	$ENV{'EUCALYPTUS'} = "";
};

if( $rev_no == 0 ){
	print "Could not find the REVISION NUMBER\n";
};

if( $clc_ip eq "" ){
	print "Could not find the IP of CLC\n";
};

if( $cc_ip eq "" ){
        print "Could not find the IP of CC\n";
};

if( $sc_ip eq "" ){
        print "Could not find the IP of SC\n";
};

if( $ws_ip eq "" ){
        print "Could not find the IP of WS\n";
};

if( $nc_ip eq "" ){
        print "Could not find the IP of NC\n";
};

chomp($nc_ip);

### Check SAN option
print "\n";
print "Checking SAN option in MEMO\n";
print "\n";

my $san_provider = "NO-SAN";

if( is_san_provider_from_memo() == 1 ){
	$san_provider = $ENV{'QA_MEMO_SAN_PROVIDER'};
};

print "\n";
print "SAN_PROVIDER\t$san_provider";
print "\n";


if( $san_provider ne "EmcVnxProvider" ){
	print "NOTHING TO DO HERE..\n";
	print "\n";
	exit(0);
};

if( is_use_multipathing_from_memo() == 0 ){
	print "\n";
	print "MULTIPATHING is not requested\n";
	print "NOTHING TO DO HERE..\n";
	print "\n";
	exit(0);
};
print "\n";

my $SSH_PREFIX = "ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no ";
my $SCP_PREFIX = "scp -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no ";
my $cmd = "";

for( my $i = 0; $i < @ip_lst; $i++ ){
	my $this_ip = $ip_lst[$i];
	my $this_distro = $distro_lst[$i];
	my $this_version = $version_lst[$i];
	my $this_arch = $arch_lst[$i];
	my $this_source = $source_lst[$i];
	my $this_roll = $roll_lst[$i];

	if( $this_roll =~ /SC/ ){

		print "\n";
		print "[SC " . $this_ip . "]\n";
		print "\n";

		my $last_two_hex = "";
		if( $this_ip =~ /^\d+\.\d+\.(\d+\.\d+)/ ){
			$last_two_hex = $1;
		};

		my $from = "IPADDR=.*";
		my $to = "IPADDR=\"10.109." . $last_two_hex . "\"";
		my $this_file = "./ifcfg-eth1";
		my_sed($from, $to, $this_file); 

		### COPY OVER ifcfg-eth1 FILE
		$cmd = $SCP_PREFIX . "./ifcfg-eth1 root\@$this_ip:/etc/sysconfig/network-scripts/.";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### CHECK OUT ifcfg-eth1 FILE
		$cmd = $SSH_PREFIX . "root\@$this_ip \"cat /etc/sysconfig/network-scripts/ifcfg-eth1\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### BRING eth1 UP
		$cmd = $SSH_PREFIX . "root\@$this_ip \"ifup eth1\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### CHECK OUT ifconfig
		$cmd = $SSH_PREFIX . "root\@$this_ip \"ifconfig\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### YUM INSTALL "device-mapper-multipath" package
		$cmd = $SSH_PREFIX . "root\@$this_ip \"yum -y install device-mapper-multipath\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### ENABLE MULTIPATH
		$cmd = $SSH_PREFIX . "root\@$this_ip \"mpathconf --enable\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### COPY multipath.conf to /etc/multipath.conf			### NOTE: Directory below must not be static	100212
		$cmd = $SSH_PREFIX . "root\@$this_ip \"cp -f /root/euca_builder/eee/storage-san/conf/emc/multipath.conf /etc/multipath.conf\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### START multipathd SERVICE
		$cmd = $SSH_PREFIX . "root\@$this_ip \"service multipathd start\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### COPY udev rules						### NOTE: Directory below must not be static	100212
		$cmd = $SSH_PREFIX . "root\@$this_ip \"cp -f /root/euca_builder/eee/clc/modules/storage-common/udev/12-dm-permissions.rules /etc/udev/rules.d/.\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### COPY OVER sc_storage_interface FILE
		$cmd = $SCP_PREFIX . "./sc_storage_interface root\@$this_ip:/root/.";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### ADD STORAGE_INTERFACES="iface0=br0,iface1=eth1" to eucalyptus.conf
		$cmd = $SSH_PREFIX . "root\@$this_ip \"cat /root/sc_storage_interface >> $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus.conf\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

	}elsif( $this_roll =~ /NC/ ){

		print "\n";
		print "[NC " . $this_ip . "]\n";
		print "\n";

		my $last_two_hex = "";
		if( $this_ip =~ /^\d+\.\d+\.(\d+\.\d+)/ ){
			$last_two_hex = $1;
		};

		my $from = "IPADDR=.*";
		my $to = "IPADDR=\"10.109." . $last_two_hex . "\"";
		my $this_file = "./ifcfg-eth1";
		my_sed($from, $to, $this_file); 

		### COPY OVER ifcfg-eth1 FILE
		$cmd = $SCP_PREFIX . "./ifcfg-eth1 root\@$this_ip:/etc/sysconfig/network-scripts/.";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### CHECK OUT ifcfg-eth1 FILE
		$cmd = $SSH_PREFIX . "root\@$this_ip \"cat /etc/sysconfig/network-scripts/ifcfg-eth1\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### BRING eth1 UP
		$cmd = $SSH_PREFIX . "root\@$this_ip \"ifup eth1\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### CHECK OUT ifconfig
		$cmd = $SSH_PREFIX . "root\@$this_ip \"ifconfig\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### YUM INSTALL "device-mapper-multipath" package
		$cmd = $SSH_PREFIX . "root\@$this_ip \"yum -y install device-mapper-multipath\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### ENABLE MULTIPATH
		$cmd = $SSH_PREFIX . "root\@$this_ip \"mpathconf --enable\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### COPY multipath.conf to /etc/multipath.conf			### NOTE: Directory below must not be static	100212
		$cmd = $SSH_PREFIX . "root\@$this_ip \"cp -f /root/euca_builder/eee/storage-san/conf/emc/multipath.conf /etc/multipath.conf\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### START multipathd SERVICE
		$cmd = $SSH_PREFIX . "root\@$this_ip \"service multipathd start\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### COPY udev rules						### NOTE: Directory below must not be static	100212
		$cmd = $SSH_PREFIX . "root\@$this_ip \"cp -f /root/euca_builder/eee/clc/modules/storage-common/udev/12-dm-permissions.rules /etc/udev/rules.d/.\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### COPY OVER nc_storage_interface FILE
		$cmd = $SCP_PREFIX . "./nc_storage_interface root\@$this_ip:/root/.";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);

		### ADD STORAGE_INTERFACES="iface0=eth0,iface1=eth1" to eucalyptus.conf
		$cmd = $SSH_PREFIX . "root\@$this_ip \"cat /root/nc_storage_interface >> $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus.conf\"";
		print $cmd . "\n";
		system($cmd);
		print "\n";
		sleep(1);
	};

};

print "\n";
print "\n[TEST_REPORT]\tFinished setup_multipath.pl\n";
print "\n";

exit(0);

1;


####################### SUBROUTINES ############################

sub is_san_provider_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^SAN_PROVIDER=(.+)\n/m ){
		my $extra = $1;
		$extra =~ s/\r//g;
		print "FOUND in MEMO\n";
		print "SAN_PROVIDER=$extra\n";
		$ENV{'QA_MEMO_SAN_PROVIDER'} = $extra;
		return 1;
	};
	return 0;
};

sub is_use_dev_san_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^USE_DEV_SAN=YES/m ){
		print "FOUND in MEMO\n";
		print "USE_DEV_SAN=YES\n";
		$ENV{'QA_MEMO_USE_DEV_SAN'} = "YES";
		return 1;
	};
	return 0;
};


sub is_use_multipathing_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^USE_MULTIPATHING=YES/m ){
		print "FOUND in MEMO\n";
		print "USE_MULTIPATHING=YES\n";
		$ENV{'QA_MEMO_USE_MULTIPATHING'} = "YES";
		return 1;
	};
	return 0;
};


# To make 'sed' command human-readable
# my_sed( target_text, new_text, filename);
#   --->
#        sed --in-place 's/ <target_text> / <new_text> /' <filename>
sub my_sed{

        my ($from, $to, $file) = @_;

        $from =~ s/([\'\"\/])/\\$1/g;
        $to =~ s/([\'\"\/])/\\$1/g;

        my $cmd = "sed --in-place 's/" . $from . "/" . $to . "/' " . $file;

        system("$cmd");

        return 0;
};



1;

