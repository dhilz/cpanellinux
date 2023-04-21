#!/usr/bin/perl


BEGIN {
   push(@INC,"/usr/local/cpanel");
}

use strict;
use Cpanel;
use Cpanel::Form qw(parseform);
use Cpanel::WebMail;
use Cpanel::BoxTrapper;

my $cp = Cpanel->new;
$cp->initcp((getpwuid($>))[0]);

my $webmail = Cpanel::WebMail->new();


$webmail->httpheader();
$webmail->header();

my %FORM = parseform();

my $account = $ENV{'REMOTE_USER'};

my $bxaction = $FORM{'bxaction'};

my $self = 'webmailboxtrapper.cgi';

print "<center>Boxtrapper<br><br></center>";

if ($bxaction eq "") {
   print "<center>";
   print "<form action=${self}>Status: <input type=hidden name=bxaction value=setup>";
   BoxTrapper_status($account);
   BoxTrapper_statusbutton($account);
   print "</form></center><br><br>";
   print "<table border=1 width=96%>";
   print "<tr>";
   print "<td align=center><br><a href=\"${self}?bxaction=conf\">Configure Settings</a><br><br></td>";
   print "<td align=center><br><a href=\"${self}?bxaction=editlists\">Edit White/Black/Ignore List</a><br><br></td>";
   print "<td align=center><br><a href=\"${self}?bxaction=showlog\">Review Log</a><br><br></td>";
   print "<td align=center><br><a href=\"${self}?bxaction=showq\">Review Queue</a><br><br></td>";
   print "</tr></table>";
   print "</center>";
} elsif ($bxaction eq "setup") {
   print "BoxTrapper has been ";
   BoxTrapper_changestatus($account,$FORM{'action'});
   print " on your account.";
} elsif ($bxaction eq "conf") {
   print "<center>";
   print "<form action=$self>";
   print "<input type=hidden name=bxaction value=saveconf>";
   print "<table>";
   print "<tr><td>Email addresses going to this account (comma seperated list)</td>";
   print "<td><input type=text name=froms value=\"";
   BoxTrapper_showemails($account);
   print "\"</td></td> <tr><td>How many days logs and messages in the queue should be kept</td>";
   print "<td><input type=text name=queue value=\"";
   BoxTrapper_showqueuetime($account);
   print "\"></td></td></table>";
   print "<input type=submit value=Save></form></center>";
} elsif ($bxaction eq "saveconf") {
   print "<center>";
   BoxTrapper_saveconf($account,$FORM{'froms'},$FORM{'queue'});
   print "You changes have been saved.</center>";
} elsif ($bxaction eq "showlog") {
   print "<center>";
   print "<table border=1 width=99%>";
   print "<tr>";
   BoxTrapper_logcontrols($FORM{'logdate'},$account,"showlog");
   print "</tr>";
   print "<tr>";
   print "<td align=left colspan=3><pre>";
   BoxTrapper_showlog($FORM{'logdate'},$account);
   print "</pre></td>";
   print "</tr>";
   print "</table>";
   print "</center>";
} elsif ($bxaction eq "showq") {
   print "<center>";
   print "<table border=1 width=99%>";
   print "<tr>";
   BoxTrapper_logcontrols($FORM{'logdate'},${account},"showq");
   print "</tr>";
   print "<tr>";
   print "<td align=left colspan=3>";
   print "<table border=1 width=100%>";
   print "<tr>";
   print "<td><b>From</b></td>";
   print "<td><b>Subject</b></td>";
   print "<td><b>Time</b></td>";
   print "</tr>";
   BoxTrapper_showqueue($FORM{'logdate'},$account,"${self}","showmsg");
   print "</table>";
   print "</td>";
   print "</tr>";
   print "</table>";
   print "</center>";
} elsif ($bxaction eq "showmsg") {
   print "<br>";
   print "<b>Choose an action:</b>";
   print "<form action=$self>";
   print "<input type=hidden name=bxaction value=\"msgaction\">";
   print "<input type=hidden name=q value=\"$FORM{'q'}\">";
   print "<input type=hidden name=t value=\"$FORM{'t'}\">";
   print "<input checked type=radio name=action value=\"deliverall,whitelist\"> Whitelist and deliver all messages from this sender.<br>";
   print "<input type=radio name=action value=\"deliver,whitelist\"> Whitelist and deliver this message from its sender.<br>";
   print "<input type=radio name=action value=\"deliverall\"> Deliver all messages from this sender.<br>";
   print "<input type=radio name=action value=\"deliver\"> Deliver message.<br>";
   print "<input type=radio name=action value=\"delete\"> Delete this message from the queue.<br>";
   print "<input type=radio name=action value=\"delete,blacklist\"> Delete this message from the queue and blacklist the sender.<br>";
   print "<input type=radio name=action value=\"delete,ignorelist\"> Delete this message from the queue and the sender to the ignorelist.<br>";
   print "<input type=submit value=Go>";
   print "<br><br>";
   print "<br>";
   print "<b>Message Preview</b>";
   print "<table border=1 width=100%>";
   print "<tr>";
   print "<td>";
   print "<pre>";
   BoxTrapper_showmessage(${account},$FORM{'t'},$FORM{'q'});
   print "</pre>";
   print "</td>";
   print "</tr>";
   print "</table>";
} elsif ($bxaction eq "msgaction") {
   print "The requested action was been completed: ";
   BoxTrapper_messageaction($account,$FORM{'t'},$FORM{'q'},$FORM{'action'});
} elsif ($bxaction eq "editlists") {
   print "<table border=1 width=96%> <tr>";
   print "<td align=center><br><a href=\"${self}?bxaction=whitelist\">Edit White List</a><br><br></td>";
   print "<td align=center><br><a href=\"${self}?bxaction=ignorelist\">Edit Ignore List</a><br><br></td>";
   print "<td align=center><br><a href=\"${self}?bxaction=blacklist\">Edit Black List</a><br><br></td> </tr> </table>";
} elsif ($bxaction eq "whitelist" || $bxaction eq "ignorelist" || $bxaction eq "blacklist") {
   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);
   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);


   if ($bxaction eq "whitelist") {
      print "<center>
      The white list is a list of users or subjects that will be allowed into your inbox with a confirmation.
      <br>
      <br>
      Examples:
      <table align=center border=1 bgcolor=#CCCCCC><tr><td align=left><pre><i>subject i love you
      from nick\@nicedomain.org
      from dave\@goodplace.com</i></pre></td></tr></table>";
   } elsif ($bxaction eq "blacklist") {
      print "<center>
      The black list is a list of users or subjects to prevent from emailing you.
      The user will also get a back a warning message of your choice.
      <br>
      <br>
      Examples:
      <table align=center border=1 bgcolor=#CCCCCC><tr><td align=left><pre><i>subject you are evil
      from nick\@evildomain.org
      from dave\@evilplace.com</i></pre></td></tr></table>";
   } elsif ($bxaction eq "ignorelist") {
      print "<center>
      The ignore list is a list of users or subjects to prevent from emailing you.
      <br>
      <br>
      Examples:
      <table align=center border=1 bgcolor=#CCCCCC><tr><td align=left><pre><i>subject you are evil
      from nick\@evildomain.org
      from dave\@evilplace.com</i></pre></td></tr></table>";
   }
   print "<br><br><form action=${self} method=POST>";
   print "<input type=hidden name=bxaction value=savelist>";
   print "<input type=hidden name=list value=${bxaction}>";
     print "<textarea name=page cols=60 rows=40>";

   if ($bxaction eq "whitelist") { open(LIST,"${emaildir}/.boxtrapper/white-list.txt"); }
   if ($bxaction eq "blacklist") { open(LIST,"${emaildir}/.boxtrapper/black-list.txt"); }
   if ($bxaction eq "ignorelist") { open(LIST,"${emaildir}/.boxtrapper/ignore-list.txt"); }
   while(<LIST>) { print; }
   close(LIST);
   print "</textarea><br><input type=submit value=Save></form>";
} elsif ($bxaction eq "savelist") {
   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);
   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if ($FORM{'list'} eq "whitelist") { open(LIST,">${emaildir}/.boxtrapper/white-list.txt"); }
   if ($FORM{'list'} eq "blacklist") { open(LIST,">${emaildir}/.boxtrapper/black-list.txt"); }
   if ($FORM{'list'} eq "ignorelist") { open(LIST,">${emaildir}/.boxtrapper/ignore-list.txt"); }
   print LIST $FORM{'page'};
   close(LIST);
   print "Your changes have been saved!\n";
}

if ($bxaction ne "") {
   print "<div align=center><br><br><b>[</b> <a href=$self>Go Back</a><b> ]</b></div>";
} else {
   print "<div align=center><br><br><b>[</b> <a href=\"$webmail->{urlbase}/\">Go Back</a><b> ]</b></div>";
}

$webmail->footer();
