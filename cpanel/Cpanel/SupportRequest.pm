#!/usr/bin/perl
# cpanelpro - SupportRequest.pm             Copyright(c) 1999-2004 John N. Koston
#                                 All rights Reserved.
# bdraco@darkorb.net              http://cpanel.net

package Cpanel::SupportRequest;

use Sys::Hostname;
use strict;
use Carp;

use vars qw(@ISA @EXPORT $VERSION);

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(SupportRequest_init SupportRequest_form SupportRequest_submit);

$VERSION = '1.0';

require 5.004;


sub SupportRequest_init {
   return(1);
}

sub SupportRequest_form {
   if ($Cpanel::flags !~ /pro/i) {
        print "Sorry, this copy of cPanel Pro is missing the license file!\n";
        return();
   }

   my(%SCONF);
   if (-e "/var/cpanel/pro/$Cpanel::CPDATA{'OWNER'}_support.conf") {
	   open(SUPPORTCONF,"<","/var/cpanel/pro/$Cpanel::CPDATA{'OWNER'}/support.conf");
   } else {
	   open(SUPPORTCONF,"<","/var/cpanel/pro/support.conf");
   }
   while(<SUPPORTCONF>) {
      chomp();
      my($name,$value) = split(/=/, $_);
      $SCONF{$name} = $value;
   }
   close(SUPPORTCONF);
   if ($SCONF{'type'} =~ /email/i) {
      my $email = Cpanel::CustInfo::getemail(1);
      print "<form action=submitsupport.html method=POST>\n";
      print "<table>";
      print "<tr><td>From</td><td><input type=text size=40 name=email value=\"${email}\"> <a href=\"../contact/index.html\">Change Default</a></td></tr>\n";
      print "<tr><td>Subject</td><td><input type=text size=40 name=subject value=\"\"></td></tr>\n";
      print "<tr><td valign=top>Body</td><td><textarea name=body cols=80 rows=20></textarea></td></tr>\n";
   } elsif ($SCONF{'type'} =~ /redirect/i) {
      print "You can enter a support request here: <a href=\"$SCONF{'supporturl'}\">$SCONF{'supporturl'}</a>.";
	print "<script>document.location.href = '$SCONF{'supporturl'}';</script>\n";
      return();
   } elsif ($SCONF{'type'} =~ /disable/i) {
      print "The System Admin has disabled this feature.";
      return();
   } elsif ($SCONF{'type'} =~ /web/i) {
      print "<form action=\"$SCONF{'url'}\" method=$SCONF{'method'}>\n";
      print "<table align=center>";
      my(@FIELDS) = split(/\,/, $SCONF{'fields'});
      foreach my $field (@FIELDS) {
         my($text,$name,$type,$value,$attribs) = split(/=/,$field);
         print "<tr><td>${text}</td><td>";
         if ($type =~ /textbox/i) { print "<input type=text name=\"${name}\" value=\"$value\" $attribs>"; }
         if ($type =~ /checkbox/i) { print "<input type=checkbox name=\"${name}\" value=\"$value\" $attribs>"; }
         if ($type =~ /hidden/i) { print "<input type=hidden name=\"${name}\" value=\"$value\" $attribs>"; }
         if ($type =~ /textarea/i) { print "<textarea name=\"${name}\" $attribs>$value</textarea>"; }
         print "</td></tr>\n";
      }
   } else {
      print "The System Admin has not configured this feature yet.";
      return();
   }

   print "</table>";
   print "<center><input type=submit value=Send></center></form>";
}

sub SupportRequest_submit {
   my($from,$subject,$body) = @_;

   my(%SCONF);
   if (-e "/var/cpanel/pro/$Cpanel::CPDATA{'OWNER'}/support.conf") {
	   open(SUPPORTCONF,"<","/var/cpanel/pro/$Cpanel::CPDATA{'OWNER'}/support.conf");
   } else {
	   open(SUPPORTCONF,"<","/var/cpanel/pro/support.conf");
   }
   while(<SUPPORTCONF>) {
      chomp();
      my($name,$value) = split(/=/, $_);
      $SCONF{$name} = $value;
   }
   close(SUPPORTCONF);

   my(@SUBJECT);
   push(@SUBJECT,$subject);

   if ($SCONF{'displayhostnamesubject'}) { push(@SUBJECT,"[hostname:" . hostname() . "]"); }   
   if ($SCONF{'displaydomainsubject'}) { push(@SUBJECT,"[domain:" . $Cpanel::CPDATA{'DNS'} . "]"); }   
   if ($SCONF{'displayusersubject'}) { push(@SUBJECT,"[user:" . $ENV{'REMOTE_USER'} . "]"); }   
   if ($SCONF{'displayipsubject'}) { push(@SUBJECT,"[ip:" . $ENV{'REMOTE_ADDR'} . "]"); }   
   if ($SCONF{'displaybrowsersubject'}) { push(@SUBJECT,"[browser:" . $ENV{'HTTP_USER_AGENT'} . "]"); }   

   $subject = join(" ",@SUBJECT);
   $subject =~ s/[\r\n]*//g;
   $from =~ s/[\r\n]*//g;


   my(@BODY) = split(/\n/, $body);
   undef $body;

   push(@BODY,"");
   if ($SCONF{'displayhostnamebody'}) { push(@BODY,"[hostname:" . hostname() . "]"); }   
   if ($SCONF{'displaydomainbody'}) { push(@BODY,"[domain:" . $Cpanel::CPDATA{'DNS'} . "]"); }   
   if ($SCONF{'displayuserbody'}) { push(@BODY,"[user:" . $ENV{'REMOTE_USER'} . "]"); }   
   if ($SCONF{'displayipbody'}) { push(@BODY,"[ip:" . $ENV{'REMOTE_ADDR'} . "]"); }   
   if ($SCONF{'displaybrowserbody'}) { push(@BODY,"[browser:" . $ENV{'HTTP_USER_AGENT'} . "]"); }   

   if ($SCONF{'type'} =~ /emailpipe/i) {
	   open(SENDMAIL,"|$SCONF{'emailpipecmd'}"); #safesecure2
   } else {
	   open(SENDMAIL,"|/usr/sbin/sendmail -t");
   }
   print SENDMAIL "From: ${from}\n";
   print SENDMAIL "To: $SCONF{'supportaddy'}\n";
   print SENDMAIL "Subject: ${subject}\n\n";
   foreach (@BODY) { 
	print SENDMAIL;
	print SENDMAIL "\n";
   }  
   close(SENDMAIL);
 

}

1;
