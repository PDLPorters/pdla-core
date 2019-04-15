use PDLA::Config;

do {
print "\nWARNING:
  The TriD Tk interface is has been deprecated
  and is not available for this PDLA build.  If
  you desire Tk support, please contact the PDLA
  developrs.  We're investigating more portable
  and supportable GUI options to Tk.\n";
exit; } if ($PDLA::Config{POGL_WINDOW_TYPE} eq 'glut');

print "This Tk interface has been replaced, the new Tk demo is in
Demos/TkTriD_demo.pm which can be run from the perldla prompt:
pdla> demo Tk3D\n";

print "\nHit <Enter> now to go to the Demo, any other key to exit ";
my $key = <STDIN>;
chomp($key);
exit if($key);
exec("perldla 	<<EOF
use blib
demo Tk3d
EOF");
1;
