use strict;
use warnings;

# Example of Exception
#java.lang.Exception: Cannot get database connection
#        at amdocs.aam.aaminterface.opensmartflex.requestpoller.RequestLstTrxHandler.processRequest(RequestLstTrxHandler.java:77)
# 
#
# output is supposed to be like:
# <Exception name> <count per file> <by request - class location>
#

use Getopt::Long;
my $out_filename;
my $input_filename;
my $input_mask;
my $dirname;
my $help=0;
my $debug=0;

my @results;

GetOptions("out=s" =>\$out_filename,
			"in=s"=>\$input_filename,
			"inmask=s"=>\$input_mask,
			"dirname=s"=>\$dirname,
			"help" =>\$help,
			"debug"=>\$debug,
		);
print_help(), exit(0) if $help;
#print_warning(), exit(0) if !defined($input_filename); 

#actually analizys will be executed here
if (defined($input_filename)){
	analyze_file($input_filename,$out_filename);
	typeStat();
}elsif (defined($input_mask)){
	analize_mask_files($input_mask,$dirname);
	typeStat();
}else{
	print "NO INPUT DATA. EXIT.\n";
}


sub print_help {
	my $helptext="
	Usage of AAM Upstream Log Analizer:\n
	perl log_analizer.pl --help --out=filename\n
		--help - prints this help
		--out=filename - if output requested in file
		--in=input_filename - required parameter with filename required to be analized.
		--debug - will print debug information
		--inmask=<mask of set of files> - will print common info about all files mentioned by mask
		--dirname=<directory name> - will be using directory for checking files by mask. By default will use '.' (current dir)
";
	print $helptext;
}

sub print_warning{
	my $printwarn="
	ATTENTION!!!!
	--in=filename is required parameter!!!\n
	";
	print $printwarn;
}

sub analyze_file{
	my $in_fname=shift or die "Input file name is not given to function";
	my $out_fname=shift;
	
	open(my $ifh, '<',$in_fname ) or die $!;
	
	while (<$ifh>){
		next if /^[ |\t]at/;
		if (/([^\<]+Exception)/){
			debprint ("DEBUG 1:'$_'\nE1:'$1'\n");
			my $exc_name=$1;
			#my$exc_desc=$2;
			debprint ("ExceptionName=>$exc_name\n" );
			my $nextline=<$ifh>;
			debprint ("Debug 2:'$nextline'\n");
			my ($class,$row)=get_location($nextline);
			next if !defined($class) || !defined($row);
			debprint ("ExceptionName=>$exc_name;Class=>$class;Row=$row;\n");
			calc($exc_name,$class,$row);
		}
	}

}

sub get_location{
	my $str=shift;

	my $class;
	my $row;
	if ($str =~ /\((\w+.java):(\d+)\)/){
		$class=$1;
		$row=$2;
		return ($class,$row);
	}
	return (undef,undef);
}


sub calc{
	my ($exc_name,$class,$row)=@_;
	debprint ("DEBUG ExcName:$exc_name;ExcClass:$class;ExcRow:$row;\n");
	die "not defined exception name" unless defined $exc_name;
	foreach my $exc (@results){
		if ($exc->{exception} eq $exc_name
			&& $exc->{class} eq $class
			&& $exc->{row} == $row){
			$exc->{count}=$exc->{count}+1;
			return;
		}
	}
	my $new_exc={count=>1,
				exception=>$exc_name,
				class=>$class,
				row=>$row,
			};
	push (@results,$new_exc);
	
}

sub typeStat{
	foreach my $exc (@results){
		print "Exception '$exc->{exception}' in class '$exc->{class}' at row '$exc->{row}' was raised '$exc->{count}' times\n";
	}
}

sub debprint{
	print @_ if $debug;
}

sub analize_mask_files{
	my $mask=shift or die "No mask received";
	my $dirname=shift || '.';

	#remove trailing '/' if any in the path
	$dirname=~ s|\/$||;
	
	#get list of files from path and by mask.
	my @files=<$dirname/$mask>;
	debprint ("FilePath:'$dirname/$mask'\n");
	foreach my $fname (@files){
		debprint("Filename:'$fname'\n");
		analyze_file($fname);
	}
}


