#!/usr/bin/perl -w

use strict;
use diagnostics;
use Tie::File;
use File::Path qw( make_path );
use Getopt::Std;


# script usage
sub usage()
{
    print "This program process log data;

    usage: $0 [-h] [-i in] [-o out]

     -h        : this (help) message
     -i in     : in file containing raw data
     -o out    : out file containing process result

    example: $0 -i in -o out";

    exit 1;
}

# split the log file with given features
# argv[0] start point
# argv[1] end point
# argv[2] raw data file handler
# return the directory of all aplite sub log
sub cut_log($; $; $) {
    my $spoint = shift @_;
    my $epoint = shift @_;
    *FH_LOG = shift @_;

    my $dir = "log";
    
    if ( !-d $dir ) {
        make_path $dir or die "Failed to create path: $dir";
    } else {
        unlink glob "$dir/*";
    }
    
    my $start = 0;
    my $count = 1;
   	while (my $line = <FH_LOG>) {
		chomp($line);
        if ($line =~ /^\d+/) {
            my @data = split / /, $line;
            if ($data[0] eq $spoint || $start eq 1) {
                if ($start eq 0) {
                    my $suffix = sprintf("%02d", $count);
                    my $data_file = $dir."/"."data".$suffix.".txt";
                    open(DATA_FILE, ">", $data_file)
                        or die "can't open $data_file $!";
                    
                    my $csv_file = $dir."/"."data".$suffix.".csv";
                    open(CSV_FILE, ">", $csv_file)
                        or die "can't open $csv_file $!";

                	$start = 1;
                }
                
                print DATA_FILE "$line\n";
                
                foreach(@data) {
					print CSV_FILE "$_,";
                }
				print CSV_FILE "\n";
                if ($data[0] eq $epoint) {
                    $start = 0;
                    $count += 1;
                    close(DATA_FILE);
                    close(CSV_FILE);
                }
            }
        }
    }
    
    return $dir;
}

# process the log bas been cut from raw file
# argc[0] filename
# argc[0] output handler
sub proc_data($; $) {
    my $filename = shift @_;
    *TO = shift @_;
    
    open(DATA_FILE, "<", $filename)
        or die "can't open $filename $!"; 
    
    my $maxval = 0;
    while (<DATA_FILE>) {
        my $line = $_;
        my @data = split / /, $line;

        if ($maxval < $data[4]) {
            $maxval = $data[4];
        }
    }
    
    close(DATA_FILE);
    
    my @file = split /\//, $filename; 
    printf "%-10s\t\t%-10f\n", $file[1], $maxval;
    printf TO "%-10s\t\t%-10f\n", $file[1], $maxval;
}


# dos2unix : perl -i -pne 's/\r\n/\n/g' log
# unix2dos : perl -i -pne 's/\n/\r\n/g' log

# install Excel::Writer::XLSX
# For windows
# open CPAN Client (Strawberry Perl/Tools) console
# input install Excel::Writer::XLSX

################################################################################
##                               main dunction                                ##
################################################################################
my %opts;
getopts('hi:o:', \%opts) or usage();
usage() if $opts{'h'};

my $in = $opts{'i'};
my $out = $opts{'o'};

my $raw;
if (!$in) {
    $raw = "APQ044W0000_F1_rejects_25C.prm";
} else {
    $raw = $in;
}
open(RAW_FH, '<', $raw) or die "Can't open $raw $!";

my $log;
if (!$out) {
	$log = "result.txt";
} else {
	$log = $out;
}
open(LOG_FH, '>', $log) or die "Can't open $log $!";

print "\nprocess......\n";

# define the start and end point to cut file
my ($spoint, $epoint) = (1540, 1890);

my $dir;
# split the file and return the directory
$dir = cut_log($spoint, $epoint, \*RAW_FH);

my @files= glob "$dir/data*.txt";

print  '-'x32, "\n";
printf "%-10s\t\t%-10s\n", "log/name", "max/val";
print  '-'x32, "\n";
print  LOG_FH '-'x32, "\n";
printf LOG_FH "%-10s\t\t%-10s\n", "log/name", "max/val";
print  LOG_FH '-'x32, "\n";
foreach my $file (@files) {
    proc_data($file, \*LOG_FH);
}
print '-'x32, "\n";
print LOG_FH '-'x32, "\n";

close(RAW_FH);
close(LOG_FH);

print "\nfinished!\n";
print "press ENTER to exit";
<STDIN>;

exit 1;
################################################################################
    

