#!/usr/bin/perl
#WHMADDON:configsupport:Configure Support Request Submission

BEGIN {
   push(@INC,"/usr/local/cpanel");
   push(@INC,"/usr/local/cpanel/whostmgr/docroot/cgi");
}

use whmlib;
require 'parseform.pl';

my %FORM = parseform();

print "Content-type: text/html\r\n\r\n";

defheader("Support Request Configuration");

if (! -e "/var/cpanel/pro") {
	mkdir("/var/cpanel/pro",0755);
}

if ($ENV{'REMOTE_USER'} ne "root") {
   $conffile = "/var/cpanel/pro/$Cpanel::CPDATA{'OWNER'}_support.conf";
} else {
   $conffile = "/var/cpanel/pro/support.conf";
}

if ($FORM{'cgiaction'} eq "") {
   open(SUPPORTCONF,$conffile);
   while(<SUPPORTCONF>) {
      chomp();
      my($name,$value) = split(/=/, $_);
      $SCONF{$name} = $value;
   }
   close(SUPPORTCONF);

   $CONFNAME{'displayhostnamesubject'} = "Display the hostname of the server in the subject.";
   $CONFNAME{'displaydomainsubject'} = "Display the customer\'s domain name in the subject.";
   $CONFNAME{'displayusersubject'} = "Display the customer\'s username in the subject.";
   $CONFNAME{'displayipsubject'} = "Display the customer\'s client ip in the subject."; 
   $CONFNAME{'displaybrowsersubject'} = "Display the customer\'s browser in the subject.";
   $CONFNAME{'displayhostnamebody'} = "Display the hostname of the server in the body.";
   $CONFNAME{'displaydomainbody'} = "Display the customer\'s domain name in the body.";
   $CONFNAME{'displayuserbody'} = "Display the customer\'s username in the body.";
   $CONFNAME{'displayipbody'} = "Display the customer\'s client ip in the body.";
   $CONFNAME{'displaybrowserbody'} = "Display the customer\'s browser in the body.";

   my $emailchecked='checked';
   my $redirectchecked='';
   my $disablechecked='';

   if ($SCONF{'type'} =~ /redirect/i) { $redirectchecked = 'checked'; $emailchecked = ''; $disablechecked=''; }
   if ($SCONF{'type'} =~ /disable/i) { $redirectchecked = ''; $emailchecked = ''; $disablechecked='checked'; }

   print "This feature allows you to configure where support requests go when they
   are submitted though cPanel.<br><br>\n";
   print "<form action=\"addon_configsupport.cgi\">";
   print "<input type=hidden name=cgiaction value=save>";
   print "<input type=radio name=type value=email $emailchecked>";
   print "Email support requests to <input size=40 type=text name=supportaddy 
   value=\"$SCONF{'supportaddy'}\">";
   print " or Pipe support requests to <input size=60 type=text name=emailpipecmd 
   value=\"$SCONF{'emailpipe'}\">";
   print "<blockquote>";
   foreach my $conf (sort keys %CONFNAME) {
      my $checked = '';
      if ($SCONF{$conf} eq "1") { $checked = 'checked'; }
      print "<input type=checkbox value=1 name=\"$conf\" $checked> $CONFNAME{$conf}<br>";
   }
   print "</blockquote>";
   print "<br>";
   print "<input type=radio name=type value=redirect $redirectchecked>";
   print "Redirect the user to the following url: <input type=text name=supporturl 
   value=\"$SCONF{'supporturl'}\" size=100>.<br>";
   print "<input type=radio name=type value=disable $disablechecked> Disable this 
   feature.<br><br>";

   print "<input type=submit value=Save>";
} elsif ($FORM{'cgiaction'} =~ /save/i) {
   delete $FORM{'cgiaction'};
   open(SUPPORTCONF,">$conffile");
   foreach my $var (sort keys %FORM) {
      print SUPPORTCONF "${var}=$FORM{$var}\n";
   }
   close(SUPPORTCONF);
   print "Your selection has been saved.\n";
}

1;

