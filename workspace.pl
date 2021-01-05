#!/usr/bin/perl
use warnings;
use strict;
use open IO => ':encoding(UTF-8)', ':std';
use utf8;
use feature qw{ say };
use 5.18.2;
#use String::ShellQuote;
#$string = shell_quote(@list);
#use Data::Dumper;
use JSON qw( decode_json  encode_json to_json from_json);
#use Encode;
use File::Slurp qw(read_file);
my $home = $ENV{HOME};
(my $date = `date +'%Y-%m-%d_%H.%M.%S'`) =~ s/\n//;
my $help = "";
my $string = "";
my $number = "";
use Getopt::Long;
my $push = "";
my $pull = "";
my $patch		 = "";
GetOptions (
    "string=s" => \$string, 
    "help" => \$help, 
    "number=f" => \$number, 
    "push" => \$push,
    "pull" => \$pull,
    "patch" => \$patch		,
    ) or die("Error in command line arguments\n");


my @a = qw{zenodo-lib
    zotero-lib
    zotzen-lib
    zenodo-cli
    zotero-cli
    zotzen-cli};

$push = 1 if $patch;
$pull = 1 if $push;

my $mydir = ".";
opendir(my $dh, $mydir) || die "Can't opendir $mydir: $!";
my @dirs = grep { !m/^\./ && -d "$mydir/$_" && -f "$mydir/$_/package.json"} readdir($dh);
closedir $dh;
my %v;

if (@ARGV) {
    @dirs = @ARGV;
} else {
    @dirs = @a;
};

my $i = 0;
if ($pull) { foreach my $file (@dirs) {
    if (-d $file) {
	$i++;
	say "\n\n*** $file ($i) ***\n";
	if (-d "$file/.git") {
	    system("chdir $file; git fetch --all; git pull --all");
	    if ($push) {
		system("chdir $file; git add .; git commit -m 'Tidy up'; git push");
		#say "Has this repo moved?";
		#my $x = <STDIN>;
		#chomp($x);
		#if ($x =~ m/\w/) {
		#    system "chdir $file; git remote set-url origin $x";
		#};
	    }
	} else {
	    say "[Not a github repo.]";
	};
    };
}};


sub getdeps() {
    my %v = ();
    say "[Getting dependencies]";
    foreach my $dir (@a) {
	#say "- $dir";
	my $file = "$mydir/$dir/package.json";
	my $f = read_file($file);
	my $g = from_json($f);
	$v{$g->{"name"}} = $g->{"version"};    
    }
    return %v;
};

sub replace() {
    my ($file,$lib,$current,$new) = @_;
    system("backup",$file);
    my $content = read_file($file);
    if ($content =~ s/\"$lib\"\:\s+\"\^?$current\"/\"$lib\"\: \"\^$new\"/sg) {
	open G,">$file";
	print G $content;
	close G;
    };
};

my $i = 0;
foreach my $dir (@dirs) {
    %v = getdeps();
    $i++;
    say "\n\n*** $dir ($i) ***\n";
    my $file = "$mydir/$dir/package.json";
    my $f = read_file($file);
    my $g = from_json($f);
    my $n = $g->{"name"};
    say "($dir) $n, $v{$n}";
    my %d = %{$g->{"dependencies"}};
    #say "Dep's:\tlib\tver\tavailable";
    say "Dependencies:";
    foreach (keys %d) {
	if ($v{$_}) {
	    say "\t$_\t$d{$_}\t(available: $v{$_})";
	    $d{$_} =~ s/\^//;
	    if ($d{$_} ne $v{$_}) {
		say "Upgrade? y/n";
		my $x = <STDIN>;
		chomp($x);
		if ($x eq "y") {
		    &replace($file,$_,$d{$_},$v{$_});
		    # system("emacs","-nw","$mydir/$dir/package.json");
		};	
	    };
	};
    };
    system("chdir $dir; npm install");
    if ($patch) {
	say "patch";
	system("chdir $dir; git add .; git commit -m 'bumping patch'; git push");
	system("chdir $dir; npm run publish:patch");
    }
};

exit();
