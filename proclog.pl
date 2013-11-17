#!/usr/bin/perl -w

use strict;
use diagnostics;
use Tie::File;
use File::Path qw( make_path );
use Getopt::Std;

use Excel::Writer::XLSX;

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
# argv[2] array of whole log file
# return the directory of all aplite sub log
sub cut_log($; $; @) {
    my $spoint = shift @_;
    my $epoint = shift @_;
    my @lines = @_;

    my $dir = "log";
    
    if ( !-d $dir ) {
        make_path $dir or die "Failed to create path: $dir";
    } else {
        unlink glob "$dir/*";
    }
    
    my $start = 0;
    my $count = 1;
    my $workbook;
    my $worksheet;
    my $format;
    my $row = 0;
    my $col = 0;
    foreach my $line (@lines) {
        if ($line =~ /^\d+/) {
            my @data = split / /, $line;
            if ($data[0] eq $spoint || $start eq 1) {
                if ($start eq 0) {
                    my $suffix = sprintf("%02d", $count);
                    my $file = $dir."/"."data".$suffix.".txt";
                    open(DATA_FILE, ">", $file)
                        or die "can't open $file $!";
                    
                    $workbook = Excel::Writer::XLSX->new( $file.'.xlsx' );
                    $worksheet = $workbook->add_worksheet();
                    $format = $workbook->add_format();
                    $format->set_align( 'center' );

                	$start = 1;
                }
                
                print DATA_FILE "$line\n";
                
                foreach(@data) {
                    $worksheet->write( $row, $col, $_, $format);
                    $col += 1;
                }
                $col = 0;
                $row += 1;
                if ($data[0] eq $epoint) {
                    $start = 0;
                    $count += 1;
                    $row = 0;
                    close(DATA_FILE);
                    $workbook->close();
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
    printf TO "%-10s\t\t%-10f\n", $file[1], $maxval;
}


# dos2unix : perl -i -pne 's/\r\n/\n/g' log
# unix2dos : perl -i -pne 's/\n/\n\r/g' log

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

if ($out) {
    open(FH, '>', $out) or die "Can't open $out $!";
} else {
    open(FH, '>&', \*STDOUT) or die "Can't redirect FH to STDOUT $!";
}

my $logfile;
if (!$in) {
    $logfile = "APQ044W0000_F1_rejects_25C.prm";
} else {
    $logfile = $in;
}

print "\nprocess......\n";

my @lines;
tie(@lines,'Tie::File',$logfile) or die "Can't open $logfile";


# define the start and end point to cut file
my ($spoint, $epoint) = (1540, 1890);

my $dir;
# split the file and return the directory
$dir = cut_log($spoint, $epoint, @lines);
untie(@lines);

my @files= glob "$dir/data*.txt";

print  FH '-'x32, "\n";
printf FH "%-10s\t\t%-10s\n", "log/name", "max/val";
print  FH '-'x32, "\n";
foreach my $file (@files) {
    proc_data($file, \*FH);
}
print FH '-'x32, "\n";

close(FH);

print "\nfinished!\n";
print "press ENTER to exit";
<STDIN>;

exit 1;
################################################################################
    

