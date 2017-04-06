#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use lib dirname (__FILE__);
use aomisc;

my $PWD  = pwd_for_hpc();

my $SORTSAM = $PWD . "/picard.jar SortSam";
my $BWA=$PWD."/bwa";
my $INTERSECTBED=$PWD."/intersectBed";
my $BAMTOBED=$PWD."/bamToBed";
my $GET_MAJORITY_START_STOP_PL=$PWD."/get_majority_start_stop.pl";
my $SAMTOOLS=$PWD."/samtools";
my $JAVA='java';
my $p=8;						# Number of threads to use for BWA. 

my %options;
$options{ref} = '';		# eg data_default/Seq12_093009_HA_cds.fa
$options{fastq} = '';
$options{p} = 8;

GetOptions(\%options,
           'ref=s',
	   'fastq=s',
	   'output_dir=s'
	   );

my $usage="
OPTIONS:
-ref		Reference sequence.  Required.
-fastq		Fastq input file.  Required.
-output_dir		Output directory.  Required.
-p		Number of threads for BWA.  Default = 8.
";

die "I need a ref file (-ref)\n$usage\n". $! if (($options{ref} eq '') || (! -e $options{ref}));
die "I need a fastq file (-fastq)\n". $! if (($options{fastq} eq '') || (! -e $options{fastq}));
die "I need an output_dir (-output_dir)\n". $! if ($options{output_dir} eq '');
$options{output_dir} =~ s/\/$//;

system ("mkdir $options{output_dir}") unless -e $options{output_dir};
die "failed to make output dir $options{output_dir}\n".$! unless -d $options{output_dir};

#system ("cp $options{ref} $options{fastq} $options{output_dir}");		# commented out by Andrew O. for now.  2016-01-09.
my ($ref,$fastq) = map{$options{output_dir}.'/'.extract_file_name($_)}($options{ref},$options{fastq});
die "failed to copy files properly $ref,$fastq\n".$! unless ((-e $ref) && (-e $fastq));

# # Check to see that the reference is indexed.  If not, attempt to index it
# system ("$BWA index $ref") unless -e $ref.'.bwt';
# die "I tried to index $ref but failed.".$! unless  -e $ref.'.bwt';

# Check to see if SortSam.jar is present
#die unless -e $SORTSAMJAR;

# Align with bwa mem
my $bwaopts="-t $p -M -B 1";
my $tmp_sam = $fastq.'.sam.gz';
#my $bwa_cmd = "$BWA mem $bwaopts $ref $fastq | gzip > $tmp_sam";
my $bwa_cmd = "$BWA mem $bwaopts $options{ref} $fastq | gzip > $tmp_sam";
system($bwa_cmd);

# Sort and index the alignment bam file
my $tmp_bam = $fastq.'.bam';
system "$JAVA -Xmx3G -jar $SORTSAM I=$tmp_sam O=$tmp_bam CREATE_INDEX=true SO=coordinate\n";

# Get the majority start stop bed file (single bed region)
my $tmp_bed=$fastq.'.temp_majority.bed';
system "$BAMTOBED -cigar -i $tmp_bam | awk '\$NF !~ /H|S/{print}' | $GET_MAJORITY_START_STOP_PL > $tmp_bed";

# Intersect bam file with majority bed region (-f 1 -r so that all read alignments start and end at the majority positions)
my $finalbam= $fastq.'.majority.bam';
$finalbam =~ s/\.fastq//;

system("$INTERSECTBED -abam $tmp_bam -b $tmp_bed -f 1 -r -u > $finalbam");

sub extract_file_name{
    my $file = shift;
    my @a = split /\//,$file;
    return $a[$#a];
}
