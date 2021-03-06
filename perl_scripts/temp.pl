use strict;
use File::Glob;
use Getopt::Long;
use Cwd;
use File::Spec;
use Carp;
use File::Basename; # for fileparse

#----------------------------------------------------------
sub Usage
{
   my $err = shift;
   my $sep = "="x60 . "\n";

   print $sep;
   if ($err) 
   {
      print "= Error: $err\n";
      print $sep;
   }

   print << "EOU__";
= $0 
= Options:
=  -verbose 
=  -clean <performs a clean build>

$sep
EOU__
exit(1);
}

my $gModVerbose = 0;
my $gPreviewOnly = 0;
my $gInitialWorkDir = "";

sub SetVerboseMode { $gModVerbose = $_[0]; }
sub SetPreviewMode { $gPreviewOnly = $_[0]; }

# input: verbose-mode-flag
sub OnApplicationStartup
{
    SetVerboseMode($_[0]);
    SetPreviewMode($_[1]);
    $gInitialWorkDir = getcwd;
}

sub OnApplicationExit
{
    chdir($gInitialWorkDir);
}

sub StartingWorkDir {return $gInitialWorkDir;}

sub PrintIfVerboseMode($)
{
    if ($gModVerbose) {
        print "$_[0]";
    }
}

# UTILITY function
# Expects absolute path
# returns name, dir, extension. 
# Extension includes "." in the beginning
sub ParseFilePathComponents
{
    return fileparse($_[0], qr/\.[^.]*/);
}

my $errMatch = qr/if errorlevel 1 goto error/;
my $match1 = qr/cd nextgen\\ansoftcore/;
my $match2 = qr/cd nextgen/;
my $match3 = qr/cd ansoftcore/; 
my $match4 = qr/cd \.\./; 
my $match5 = qr/Nextgen_NoHfss/; # Designer-UI
my $match6 = qr/hfss all_hfss|maxwelllight all_maxwell/; # 3D-UI
my $match7 = qr/goto finish/;

my $disableErrCheck = 0;

sub ProcessFile
{
  my $fileHandle;
  my $currFilePath = $_[0];
  open($fileHandle, "< $currFilePath") or die "Unable to open '$_[0]' for reading";
  my @newLines;
  my @fileLines = <$fileHandle>;
  foreach(@fileLines) {
      my $skipLine = 0;
      if (/$match1/) {
	  s/$match1/cd build\\OfficialSln/g;
      } elsif (/$match2/) {
	  s/$match2/cd build\\OfficialSln/g;
      } elsif (/$match3/) {
	  $skipLine = 1;
	  $disableErrCheck = 1;
      } elsif (/$match4/) {
	  $skipLine = 1;
	  $disableErrCheck = 1;
      } elsif ($disableErrCheck && /$errMatch/) {
	  $skipLine = 1;
	  $disableErrCheck = 0;
      } elsif (/$match5/) {
	  s/($match5)/Designer-UI/g;
      } elsif (/$match6/) {
	  s/($match6)/3D-UI/g;
	  push(@newLines, "call buildsln_debug64.bat MCAD\n");
      } elsif (/$match7/) {
	  push(@newLines, "cd ..\\..\n\n");
      }

      next if ($skipLine);

      chomp($_);
      push(@newLines, "$_\n");
  }

  my $outputFileHandle;
  open($outputFileHandle, ">$currFilePath") or die "Unable to open file '$currFilePath' for writing";
  foreach(@newLines) {
      print $outputFileHandle $_;
  }

}


# TEMPLATE FUNCTION
# Purpose: 
#     - For each file in *current* directory, do action
#     - Recursively drills down
# CUSTOMIZE: Edit or read file. (Note: Not inteneded to work in cases requiring deletion or creation of files in visited directories)
#            Edit caller to switch current directory to target directory
sub DoEditOrReadOfFile
{
    my $currFile = $_[0];
    
    my $matchBuildScript = qr/build.+\.bat/;
    my $matchAIMBuildScript = qr/buildaim.+\.bat/;
    return if ($currFile =~ m/$matchAIMBuildScript/);
    return if !($currFile =~ m/$matchBuildScript/);

    ProcessFile($currFile);
}

sub DoActionForFilesInCurrDir
{
    my $dirHandle;
    opendir($dirHandle, ".") or die "Unable to open current directory";
    
    my @dirFiles = readdir($dirHandle) or die "Unable to read directory contents of current directory";
    
    foreach(@dirFiles) {
	next if ($_ eq "." || $_ eq "..");
	my $dirPath = "./$_";
	if (-d $dirPath) {
	} else {
            # CUSTOMIZE
	    DoEditOrReadOfFile($dirPath);
	}
    }
}

MAIN:
{

    my ($verbose, $preview) = (0, 0);
    GetOptions("verbose" => \$verbose, "preview" => \$preview) or Usage("Incorrect command-line");

    OnApplicationStartup($verbose, $preview);

    my $startWorkDir = StartingWorkDir;
    print "Starting workdir is '$startWorkDir'\n";

    DoActionForFilesInCurrDir();

    OnApplicationExit;
}
