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
use Getopt::Long;
my $help = "";
my $push = "";
my $pull = "";
my $patch = "";
my $clone = "";
my $install = "";
my $self = "";
my $message = "";
my $global = "";
my $reglobal = "";
my $autoup = "";
GetOptions (
    "help" => \$help, 
    "push" => \$push,
    "pull" => \$pull,
    "patch" => \$patch		,
    "clone" => \$clone,
    "install" => \$install,
    "self" => \$self,
    "message=s" => \$message,
    "global" => \$global,
    "reglobal" => \$reglobal,
    "autoup" => \$autoup,
    ) or die("Error in command line arguments\n");

if ($message) {
    $message = " " . $message
}

my @a = qw{zenodo-lib
    zotero-lib
    zotzen-lib
    zenodo-cli
    zotero-cli
    zotzen-cli};

if ($help || (!$self && !$push && !$pull && !$install && !$patch && !$global && !$reglobal)) {
say "
$0

--clone
--pull
--push
--install
--patch
--self 


--clone
        CLone all zotero/zenodo repositories.
--pull
        Pull all zotero/zenodo repositories.
--push
        Pull, then push, all zotero/zenodo repositories.

--install
        Pull, then npm install
--patch
        Pull, push, npm install and npm publish:patch
--global
        Install CLIs globally.
--reglobal
        Remove CLIs globally first, then reinstall

--self 
        Pull/push this script.


";
};


if ($self) {
    system "git pull; git add .; git commit -m \"Updating workspace tool\"; git push";
    exit;
}

if ($clone) {
    say "Cloning repositories.";
    foreach (@a) {
	if (!-e $_) {
	    system("git clone git\@github.com:OpenDevEd/$_.git");
	    # https://github.com/OpenDevEd/zotero-lib.git
	} else {
	    say "Repo $_ already exists.";
	};
    };
    say "Done cloning repositories.";
    exit;
}

$push = 1 if $patch;
$pull = 1 if $push;
$install = 1 if $patch;
$pull = 1 if $install;

#my $mydir = ".";
#opendir(my $dh, $mydir) || die "Can't opendir $mydir: $!";
#my @dirs = grep { !m/^\./ && -d "$mydir/$_" && -f "$mydir/$_/package.json"} readdir($dh);
#closedir $dh;

my %v;

my @dirs;
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
		system("chdir $file; git add .; git commit -m 'zotzen-workspace (tidy up)$message'; git push");
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
	my $file = "$dir/package.json";
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



$i = 0;
if ($install) { foreach my $dir (@dirs) {
    %v = getdeps();
    $i++;
    say "\n\n*** $dir ($i) ***\n";
    my $file = "$dir/package.json";
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
		my $x = "y";
		if (!$autoup) {
		    say "(You can enable autoupdate with --autoup.)";
		    say "Upgrade? y/n";
		    $x = <STDIN>;
		    chomp($x);
		}
		if ($x eq "y") {
		    &replace($file,$_,$d{$_},$v{$_});
		    # system("emacs","-nw","$mydir/$dir/package.json");
		};	
	    };
	};
    };
    system("chdir $dir; npm install; npm run build");
    if ($patch) {
	say "patch";
	system("chdir $dir; git add .; git commit -m 'zotzen-workspace (bumping patch)$message'; git push");
	system("chdir $dir; npm run publish:patch");
    }
};};


if ($global || $reglobal) {
    my $login = (getpwuid $>);
    if ($login ne 'root') {
	say "\n\nYou may have to enter the super user password to install globally.\n";
    };    
    foreach my $dir (@dirs) {
	if ($dir =~ m/cli$/) {
	    if ($reglobal) {
		say "\nUninstalling CLI: $dir";
		system("sudo npm uninstall -g $dir");
	    };
	    say "\nInstalling CLI: $dir";
	    system("sudo npm install -g $dir");
	};
    };
};
exit();
