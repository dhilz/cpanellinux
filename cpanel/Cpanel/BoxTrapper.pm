#!/usr/bin/perl
# cpanelpro - BoxTrapper.pm             Copyright(c) 1999-2004 John N. Koston
#                                 All rights Reserved.
# bdraco@darkorb.net              http://cpanel.net

package Cpanel::BoxTrapper;

use strict;
use Carp;

use vars qw(@ISA @EXPORT $VERSION);

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);

@EXPORT = qw(BoxTrapper_init BoxTrapper_gettransportmethod BoxTrapper_findreturnaddy BoxTrapper_checkdeadq BoxTrapper_clog
BoxTrapper_loadconf BoxTrapper_getqueueid BoxTrapper_queuemessage BoxTrapper_sendformmessage BoxTrapper_checklist
BoxTrapper_delivermessage BoxTrapper_extractaddresses BoxTrapper_splitaddresses BoxTrapper_extractaddress
BoxTrapper_getheader BoxTrapper_getsender BoxTrapper_getheaders BoxTrapper_getdomainowner BoxTrapper_beginmatch
BoxTrapper_gethomedir BoxTrapper_popsafeclose BoxTrapper_popsafeopen BoxTrapper_getranddata BoxTrapper_getourid
BoxTrapper_addaddytolist BoxTrapper_isfromself BoxTrapper_isinarray BoxTrapper_loopprotect BoxTrapper_getemaildirs
BoxTrapper_getaccountinfo BoxTrapper_getwebdomain BoxTrapper_accountmanagelist BoxTrapper_listpops BoxTrapper_isenabled
BoxTrapper_status BoxTrapper_statusbutton BoxTrapper_changestatus BoxTrapper_logdate BoxTrapper_logcontrols
BoxTrapper_showlog BoxTrapper_nicedate BoxTrapper_cleanfield BoxTrapper_showemails BoxTrapper_showqueuetime
BoxTrapper_saveconf BoxTrapper_getboxconfdir BoxTrapper_showqueue BoxTraper_extractfrom
BoxTrapper_showmessage BoxTrapper_messageaction BoxTrapper_listmsgs BoxTrapper_editmsg
BoxTrapper_resetmsg);

$VERSION = '1.0';

require 5.004;


sub BoxTrapper_init {
   return(1);
}

sub BoxTrapper_gettransportmethod {
   my($header) = @_;
   $header =~ /^from\s+.*\s+by\s+\S+\s+with\s+(\S+)/;
   return($1);
}

sub BoxTrapper_findreturnaddy {
   my($account,$okaddys,@ALLADDYS) = @_;

   my @OKADDYS = split(/\,/, $okaddys);

   foreach my $okaddy (@OKADDYS) {
      foreach my $emailaddy (@ALLADDYS) {
         if ($okaddy eq $emailaddy) {
            return($okaddy);
         }
      }
   }

   return($account);
}

sub BoxTrapper_checkdeadq {
   my($emaildir,$rconf) = @_;
   my %CONF = %{$rconf};

   my $now = time();

   my $killtime = $CONF{'stale-queue-time'};

   $killtime = ($killtime * 86400); #time in seconds	

   my @DIRS=("boxtrapper/queue","boxtrapper/verifications","boxtrapper/log");

   foreach my $dir (@DIRS) {
      opendir(QF,"${emaildir}/${dir}");
      my @QFS = readdir(QF);
      closedir(QF);

      foreach my $qf (@QFS) {
         if (-f "${emaildir}/${dir}/${qf}" && 
         (stat("${emaildir}/${dir}/${qf}"))[9] + $killtime < $now ) {
            unlink("${emaildir}/${dir}/${qf}");
            BoxTrapper_clog(2,$emaildir,"Unlinking ${emaildir}/${dir}/${qf} because its older then ${killtime} seconds\n");
         }
      }
   }

}

sub BoxTrapper_clog {
   my($loglevel,$emaildir,$log) = @_;


   my($mon,$mday,$year) = BoxTrapper_nicedate(time());

   if (! -e "${emaildir}/boxtrapper") {
      mkdir("${emaildir}/boxtrapper",0700);
   }
   if (! -e "${emaildir}/boxtrapper/log") {
      mkdir("${emaildir}/boxtrapper/log",0700);
   }

   open(CLOG,">>","${emaildir}/boxtrapper/log/${mon}-${mday}-${year}.log");
   print CLOG "$log\n";
   close(CLOG); 
}

sub BoxTrapper_loadconf {
   my($emaildir,$account) = @_;
   my %CNF;

   open(CF,"<","${emaildir}/boxtrapper.conf");
   while(<CF>) {
      chomp();
      my($name,$value) = split(/=/, $_, 2);
      if ($name ne "") {
         $CNF{$name} = $value;
      }
   }
   close(CF);

   if ($CNF{'stale-queue-time'} eq "") { $CNF{'stale-queue-time'} = 15; }
   if ($CNF{'froms'} eq "") { $CNF{'froms'} = $account; }

   return(%CNF);
}

sub BoxTrapper_getqueueid {
   my($dir) = @_;
   my($queuedir) = $dir . "/boxtrapper/queue/";
   my($randdata);
   my($rndfile);
   alarm(50);
   while (-e "${queuedir}/${rndfile}.msg" || $rndfile eq "") {
      $rndfile = BoxTrapper_getranddata(32,1);
   }
   alarm(0);
   return($rndfile . ".msg");
}

sub BoxTrapper_queuemessage {
   my($dir,$email,$msgid) = @_;
   $email =~ s/\.\.//g;
   $email =~ s/\///g;

   $msgid =~ s/\.msg$//g;

   my $mboxlock = BoxTrapper_popsafeopen(\*MBOX,">>",$dir . "/boxtrapper/verifications/" . $email);
   print MBOX "${msgid}\n";
   BoxTrapper_popsafeclose(\*MBOX,$mboxlock);
}


sub BoxTrapper_sendformmessage {
   my($message,$emaildir,$email,$subject,$msgid,$rheaders,$webdomain,$acct,$id,$returnaddy) = @_;

   $emaildir =~ s/\.\.//g;
   $message =~ s/\.\.//g;
   
   $msgid =~ s/\.msg$//g;

   my $headers = join("\n",@{${rheaders}});

   if (-e "${emaildir}/.boxtrapper/forms/${message}.txt") {
      open(FL,"<","${emaildir}/.boxtrapper/forms/${message}.txt");	
   } else {
      open(FL,"<","/usr/local/cpanel/etc/boxtrapper/forms/${message}.txt");	
   }

   open(SM,"|/usr/sbin/sendmail -t");
   print SM "X-Boxtrapper: ${id}\n";
   print SM "From: ${returnaddy}\n";
   while(<FL>) {
      s/%acct%/${acct}/g;
      s/%msgid%/${msgid}/g;
      s/%subject%/${subject}/g;
      s/%email%/${email}/g;
      s/%headers%/${headers}/g;
      s/%webdomain%/${webdomain}/g;
      print SM;
   }
   close(SM);

   close(FL);
}

sub BoxTrapper_checklist {
   my($list,$dir,$addy,$subject) = @_;
   $dir =~ s/\.\.//g;
   $list =~ s/\.\.//g;
   
   open(MYLIST,"<","${dir}/.boxtrapper/${list}-list.txt");
   while(<MYLIST>) {
      next if BoxTrapper_beginmatch($_,"#");
      chomp();
      my($header,$match) = split(/ /, $_, 2);
      $match =~ s/\//\\\//g;

      if ($header eq "from" && $addy =~ /${match}/i) {
         close(MYLIST);
         return(1);
      }
      if ($header eq "subject" && $subject =~ /${match}/i) {
         close(MYLIST);
         return(1);
      }
   }
   close(MYLIST);

   return(0);
}


sub BoxTrapper_delivermessage {
   my($file,$hdref,$bdref) = @_;
   my(@HEADERS) = @{$hdref};

   $file =~ s/\.\.//g;
   my(@BODY);

   if ($bdref) {
      @BODY = @{$bdref};
   }
   my $mboxlock = BoxTrapper_popsafeopen(\*MBOX,">>",$file);

   foreach (@HEADERS) {
      print MBOX;
      print MBOX "\n";
   }
   print MBOX "\n";

   if ($#BODY == -1) {
      while(<STDIN>) {
         print MBOX;
      }
   } else {
      foreach (@BODY) {
         print MBOX;
      }
   }

   BoxTrapper_popsafeclose(\*MBOX,$mboxlock);
}


sub BoxTrapper_extractaddresses {
   my(@ADDRESSES) = @_;
   my(@EADDRESSES);
   foreach (@ADDRESSES) {
      push(@EADDRESSES,BoxTrapper_extractaddress($_));
   }
   return(@EADDRESSES);
}

sub BoxTrapper_extractfrom {
   my($fromline) = @_;
   my($from);

   if ($fromline =~ /\"([^"]+)\"/) {
      $from = $1;
   }

   if ($from eq "") {
      $from = BoxTrapper_extractaddress($fromline)
   }

   return($from);
}


sub BoxTrapper_splitaddresses {
   my($addresses) = @_;
   $addresses =~ s/[\s\t]*//g;
   return(split(/[\;\,]+/, $addresses));
}

sub BoxTrapper_extractaddress {
   my($email) = @_;
   $email =~ tr/[A-Z]/[a-z]/;
   $email =~ /([^\"\s\t\<]+\@[^\"\>\t\s]+)/;
   return($1);
}


sub BoxTrapper_getheader {
   my($header,$hdref) = @_;
   my(@HEADERS)=@{$hdref};

   my $hresult;
   my $nextline = 0;

   foreach (@HEADERS){ 
      if ($nextline == 1 && $hresult ne "" && /^[\t\s]+/) {
         s/^[\t\s]+/ /g;
         $hresult .= $_;
      } elsif ($nextline == 0 && /^${header}: (.*)/i) {
         if ($hresult ne "") { last; }
         $hresult = $1;         
         $nextline = 1;
      } elsif ($nextline == 1) {
#we didn't match the nextline again so bail
last;
      }
   }
   return($hresult);
}

sub BoxTrapper_getsender {
   my($hdref) = @_;
   my(@HEADERS)=@{$hdref};

   foreach (@HEADERS){ 
      if (/^From\s(\S+)/i) {
         return($1);
      }
   }
}


sub BoxTrapper_getheaders {
   my $inheader = 0;
   my $header;

   while(<STDIN>) {
      if (/^[\r\n]*$/) {last;}
      $header .= $_;
   }

   return(split(/\n/,$header));
}


sub BoxTrapper_getdomainowner {
   my($domain) = @_;
   open(USERDOMS,"/etc/userdomains");
   seek(USERDOMS,0,0);
   while(<USERDOMS>) {
      chomp();
      if (BoxTrapper_beginmatch($_,"${domain}: ")) {
         /\S+\s*(\S+)/;
         close(USERDOMS);
         return($1);
         last;
      }
   }
   close(USERDOMS);
   return("");

}


sub BoxTrapper_beginmatch {
   my($haystack,$needle) = @_;


   $haystack =~ tr/[A-Z]/[a-z]/;
   $needle =~ tr/[A-Z]/[a-z]/;
   if (substr($haystack,0,length($needle)) eq $needle) {
      return(1);
   }

   return(0);
}

sub BoxTrapper_gethomedir {
   my($user) = @_;
   my($homedir);
   open(PASSWD,"/etc/passwd");
   while(<PASSWD>) {
      if (BoxTrapper_beginmatch($_,"${user}:")) {
         (undef,undef,undef,undef,undef,$homedir,undef) = split(/:/, $_,  7);
         while(-l $homedir) {
            $homedir = readlink($homedir);
         }
         close(PASSWD);
         return($homedir);
      }
   }
   close(PASSWD);

}



sub BoxTrapper_popsafeclose {
   my($fh,$lock) = @_;
   unlink($lock);
   flock($fh,8); # 8 = lock_un
   close($fh);
}

sub BoxTrapper_popsafeopen {
   my($fh,$arg1,$arg2) = @_;
   my $mode;
   my $file;
                                                                                                                                         
   if ($arg2 eq "") {
      $file = $arg1;
   } else {
      $mode = $arg1;
      $file = $arg2;
   }
                                                                                                                                         
                                                                                                                                         
   my($opid,$omtime,$mtime,$i,$lockfile);
   $lockfile = "${file}.lock";
   $lockfile =~ s/^(\>)*//g;
   (undef,undef,undef,undef,undef,undef,undef,undef,
   undef,$omtime,undef,undef,undef)
   = stat($lockfile);

   if (-e "${file}.lock") {
      open(LCKFILE,"<","${file}.lock");
      chomp($opid = <LCKFILE>);
      close(LCKFILE);
   }

   $opid =~ /(\d+)/;
   $opid = $1;
   my $df = 0;

   if ($opid =~ /^\d+$/) {
      while(-e "/proc/$opid" && $opid ne "") {
         $df++;
         last if ($df > 300);
         sleep(1);
      }
   } else {
      my($omtime);
      my($mtime);
      my($i);
      (undef,undef,undef,undef,undef,undef,undef,undef,
      undef,$omtime,undef,undef,undef)
      = stat($lockfile);


      while(1) {
         if (-e "${file}.lock") {
            sleep(1);
            (undef,undef,undef,undef,undef,undef,undef,undef,
            undef,$mtime,undef,undef,undef)
            = stat($lockfile);
            if ($mtime == $omtime) {
# lock file has aged
$i++;
            } else {
# there is a new lock file, reset
$omtime = $mtime;
$i = 0;
            }
            if ($i == 15) {
#lock file aged 15 sec
last;
            }
         } else {
            last;
         }
      }

   }

   open(SLOCKFILE,">","${lockfile}");
   eval "print SLOCKFILE POSIX::getpid();";
   close(SLOCKFILE);

   if ($mode eq "") {
      open($fh,$file); #safesecure2
   } else {
      open($fh,$mode,$file);
   }

   unless (flock($fh,2)) { #2 = lock_ex
      warn "cannot get file lock on $file: $!\n";
   }     


   return($lockfile);
}


sub BoxTrapper_getranddata {
   my($size,$sendheader) = @_;
   if ($size eq "") { $size = 10; }
   my $readsize = ($size * 16);

   my $rndpass = '';
   open(URAND,"/dev/urandom") || do {
      print "Fatal Error: Unable to read data from /dev/urandom ($!).  Please contact your system admin to have them repair the problem.\n";
      exit(1);
   };
   while(length($rndpass) < $size) {
      read URAND,$rndpass,$readsize;
      $rndpass =~ s/\W//g;
   }
   $rndpass = substr($rndpass,0,$size);
   return($rndpass);
}


sub BoxTrapper_getourid {
   my($emaildir) = @_;
   $emaildir =~ s/\.\.//g;
   my $id;
   if (-e "${emaildir}/.boxtrapper/id") {
      open(ID,"<","${emaildir}/.boxtrapper/id");
      chomp($id = <ID>);
      close(ID);
   } else {
      $id = BoxTrapper_getranddata(32,1);
      open(ID,">","${emaildir}/.boxtrapper/id");
      print ID $id;
      close(ID);
   }
   return($id);
}

sub BoxTrapper_addaddytolist {
   my($list,$addy,$dir) = @_;
   $addy =~ s/\./\\\./g;
   $dir =~ s/\.\.//g;
   $list =~ s/\.\.//g;
  
   $addy =~ s/\n//g;
   $addy =~ s/^\s*|\s*$//g;

   return if ($addy eq "");

   open(MYLIST,">>","${dir}/.boxtrapper/${list}-list.txt");
   print MYLIST "from ${addy}\n";
   close(MYLIST);
}


sub BoxTrapper_isfromself {
   my($email,$account,$froms) = @_;

   my @accounts = split(/\,/, $froms);

   push(@accounts,$account);

   foreach my $frome (@accounts) {
      if ($email eq $frome) { return(1); }
   }

   return(0);
}


sub BoxTrapper_isinarray {
   my($item,@ARRAY) = @_;
   my($key);
   foreach $key (@ARRAY) {
      if ($key eq $item) { return 1; }
   }
   return 0;
}


sub BoxTrapper_loopprotect {
   my($from,$emaildir) = @_;
   my(%LOOPTIMES);

   $emaildir =~ s/\.\.//g;
   my $loopprofile = "${emaildir}/.boxtrapper/loopprotect";

   my $looplock = SafeFile::safeopen(\*LOOPCONTROL,"<",$loopprofile);
   while(<LOOPCONTROL>) {
      s/\n//g;
      my($email,$time) = split(/=/, $_, 2);
      $LOOPTIMES{$email} = $time;
   }
   SafeFile::safeclose(\*LOOPCONTROL,$looplock);

   my($lastrespond,$respondcount) = split(/=/ , $LOOPTIMES{$from});

   my $now = time();

   if ( ($lastrespond + (60*30)) < $now) {
      $respondcount = 0;
   }

   if ($lastrespond > $now) {
      $lastrespond = $now;
   }

   $respondcount++;

   my $looplock = SafeFile::safeopen(\*LOOPCONTROL,">","$loopprofile");

   $LOOPTIMES{$from} = "$now=$respondcount";

   foreach my $email (keys %LOOPTIMES) {
      my($rtime,$rcount) = split(/=/ , $LOOPTIMES{$email});
      if ( ($rtime + (60*60*24)) < $now) {
         next;
      }
      print LOOPCONTROL "$email=$rtime=$rcount\n";
   }
   SafeFile::safeclose(\*LOOPCONTROL,$looplock);

   if (($lastrespond + (30*60)) > $now && $respondcount > 5) {
#loopcontrol
exit(0);
   }
}


sub BoxTrapper_getemaildirs {
   my($account,$homedir) = @_;

   my $emaildir;
   my $emaildeliverdir;
   if ($account =~ /\@/) {
      my($user,$domain) = split(/\@/, $account);
      $emaildir = "${homedir}/etc/${domain}/${user}";
      $emaildeliverdir = "${homedir}/mail/${domain}/${user}";
   } else {
      $emaildir = "${homedir}/etc";
      $emaildeliverdir = "${homedir}/mail";
   }
   if (! -e $emaildir) { mkdir($emaildir,0700); }
   if (! -e $emaildeliverdir) { mkdir($emaildir,0700); }

   if (! -e "${emaildir}/.boxtrapper") {
      mkdir("${emaildir}/.boxtrapper",0700);
   }

   $emaildir =~ s/\.\.//g;
   $emaildeliverdir =~ s/\.\.//g;

   if (! -d $emaildir) { return("",""); }
   if (! -d $emaildeliverdir) { return("",""); }

   return($emaildir,$emaildeliverdir);
}


sub BoxTrapper_getaccountinfo {
   my ($account) = @_;

   my($user,$domain,$domainowner);
   if ($account =~ /\@/) {
      ($user,$domain) = split(/\@/, $account);
      $domainowner = BoxTrapper_getdomainowner($domain);
   } else {
      $domainowner = $account;
   }
   if ($domainowner eq "") { return("",""); }
   my $homedir = BoxTrapper_gethomedir($domainowner);


   return($homedir,$domain);
}


sub BoxTrapper_getwebdomain {
   my($webdomain) = @_;

   if ($webdomain eq "") { 
      chomp($webdomain = `hostname`);
   } else {
      $webdomain = "mail." . $webdomain;
   }

   return($webdomain);
}

sub BoxTrapper_status {
   my($account) = @_;


   my $enabled = BoxTrapper_isenabled($account);
   my($status);
   if ($enabled) { $status = 'enabled'; } else { $status = 'disabled'; }

   print "$status";	
}

sub BoxTrapper_statusbutton {
   my($account) = @_;


   my $enabled = BoxTrapper_isenabled($account);
   my($status);
   if ($enabled) { 
      print "<input type=submit name=action value=Disable>";
   } else {
      print "<input type=submit name=action value=Enable>";
   }
}

sub BoxTrapper_changestatus {
   my ($account,$action) = @_;
   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);
   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);
  
   
   if ($action =~ /enable/i) {
      print "enabled";
      open(BX,">","${emaildir}/.boxtrapperenable");
      close(BX);
   } else {
      print "disabled";
      unlink("${emaildir}/.boxtrapperenable");
   }

}


sub BoxTrapper_accountmanagelist {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my ($link) = @_;
   my (@POPS) = BoxTrapper_listpops();


   unshift(@POPS,"${Cpanel::user}");
   foreach my $pop (@POPS) {
      my $enabled = BoxTrapper_isenabled($pop);
      my($status);
      if ($enabled) { $status = 'enabled'; } else { $status = 'disabled'; }
      print "<tr><td>${pop}</td><td>$status</td><td><a href=\"${link}?account=${pop}\">Manage</a></td></tr>\n";
   }	

}


sub BoxTrapper_isenabled {
   my($account) = @_;


   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);
   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if (-e "${emaildir}/.boxtrapperenable") { return(1); }

   return(0);
}

sub BoxTrapper_listpops {
   my(@ARR);
   my(@ARGS) = @_;
   my $handoff = "${Cpanel::root}/cpanel-email";
   if (-e "${Cpanel::root}/cpanel-email.pl") {
      $handoff = "${Cpanel::root}/cpanel-email.pl";
   }
   open(HAND,"-|") || exec ($handoff, "listpops");
   while(<HAND>) {
      s/\n//g;
      push(@ARR,$_);
   }
   close(HAND);
   return(@ARR);
}


sub BoxTrapper_nicedate {
   my($date) = @_;	
   my($mday,$mon,$year,$hour,$min,$sec);

   ($sec,$min,$hour,$mday,$mon,$year,undef) = localtime($date);
   $year += 1900;
   $mon += 1;

   $mon = sprintf("%02d",$mon);
   $mday = sprintf("%02d",$mday);

   $sec = sprintf("%02d",$sec);
   $min = sprintf("%02d",$min);
   $hour = sprintf("%02d",$hour);

   return($mon,$mday,$year,$hour,$min,$sec);
}

sub BoxTrapper_logdate {
   my ($logdate) = @_;
   if ($logdate eq "") { $logdate = time(); }

   my($mon,$mday,$year) = BoxTrapper_nicedate($logdate);

   print "${mon}-${mday}-${year}";
}


sub BoxTrapper_showlog {
   my ($logdate,$account) = @_;
   if ($logdate eq "") { $logdate = time(); }

   my($mon,$mday,$year) = BoxTrapper_nicedate($logdate);


   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if ($emaildir eq "" || $emaildeliverdir eq "") {
      print "Email homedir for ${account} does not exist";
      return();
   }

   open(CLOG,"<","${emaildir}/boxtrapper/log/${mon}-${mday}-${year}.log");
   while(<CLOG>) {
      print BoxTrapper_cleanfield($_);
   }
   close(CLOG);
}

sub BoxTrapper_messageaction {
   my ($account,$logdate,$queuefile,$action) = @_;
   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);
   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   $queuefile =~ s/\.\.//g;
   my @ACTIONS = split(/\,/, $action);

   my(@HEADERS);
   open(QF,"<","${emaildir}/boxtrapper/queue/${queuefile}");
   while(<QF>) {
      if (/^[\r\n]*$/) {last;}
      push(@HEADERS, $_);
   }
   close(QF);

   my $email = BoxTrapper_extractaddress(BoxTrapper_getheader("from",\@HEADERS));
   $email = BoxTrapper_cleanfield($email);
   $email =~ s/\.\.//g;
   $queuefile =~ s/\.\.//g;
   
   foreach my $action (@ACTIONS) {
      if ($action eq "whitelist") {
         print "${email} was added to your white list. ";
         BoxTrapper_addaddytolist("white",$email,${emaildir})
      } elsif ($action eq "blacklist") {
         print "${email} was added to your black list. ";
         BoxTrapper_addaddytolist("black",$email,${emaildir})
      } elsif ($action eq "ignorelist") {
         print "${email} was added to your ignore list. ";
         BoxTrapper_addaddytolist("ignore",$email,${emaildir})
      } elsif ($action eq "deliverall") {
         print "queued messages from ${email} delivered. ";
         my $mboxlock = BoxTrapper_popsafeopen(\*MBOX,">>","${emaildeliverdir}/inbox");
         open(MSGIDS,"<","${emaildir}/boxtrapper/verifications/${email}");
         while(my $msgidr = <MSGIDS>) {
            chomp($msgidr);
            open(QMS,"<","${emaildir}/boxtrapper/queue/${msgidr}.msg");
            while(<QMS>) {
               print MBOX;
            }
            close(QMS);
            unlink("${emaildir}/boxtrapper/queue/${msgidr}.msg");
         }
         close(MSGIDS);
         BoxTrapper_popsafeclose(\*MBOX,$mboxlock);
	 unlink("${emaildir}/boxtrapper/verifications/${email}");
      } elsif ($action eq "deliver") {
         print "queued message from ${email} delivered. ";
         my $mboxlock = BoxTrapper_popsafeopen(\*MBOX,">>","${emaildeliverdir}/inbox");
         open(QMS,"<","${emaildir}/boxtrapper/queue/${queuefile}");
         while(<QMS>) {
            print MBOX;
         }
         close(QMS);
         BoxTrapper_popsafeclose(\*MBOX,$mboxlock);
         unlink("${emaildir}/boxtrapper/queue/${queuefile}");
      } elsif ($action eq "delete") {
         print "queued message from ${email} deleted. ";
         unlink("${emaildir}/boxtrapper/queue/${queuefile}");
      }
   }

}

sub BoxTrapper_showmessage {
   my ($account,$logdate,$queuefile) = @_;

   $queuefile =~ s/\.\.//g;
   
   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if ($emaildir eq "" || $emaildeliverdir eq "") {
      print "Email homedir for ${account} does not exist";
      return();
   }

   my $lines=0;

   open(QF,"<","${emaildir}/boxtrapper/queue/${queuefile}");
   while(<QF>) {
      $lines++;
      last if ($lines > 200);
      chomp();
      $_ = BoxTrapper_cleanfield($_);
      print;
      print "\n"; 
   }
   close(QF);



}

sub BoxTrapper_showqueue {
   my ($logdate,$account,$showfile,$bxaction) = @_;
   if ($logdate eq "") { $logdate = time(); }

   my($mon,$mday,$year) = BoxTrapper_nicedate($logdate);

   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if ($emaildir eq "" || $emaildeliverdir eq "") {
      print "Email homedir for ${account} does not exist";
      return();
   }

   my(%BXMSG);
   opendir(QDIR,"${emaildir}/boxtrapper/queue");
   my @QDIR = readdir(QDIR);
   closedir(QDIR);
   @QDIR = grep(!/^\./, @QDIR);
   my $i = 0;
   foreach my $queuefile (@QDIR) { 
      my $tt = (stat("${emaildir}/boxtrapper/queue/${queuefile}"))[9];
      my($qmon,$qmday,$qyear,$qhour,$qmin,$qsec) = BoxTrapper_nicedate($tt);
      if ($qmday == $mday && $qmon == $qmon && $qyear == $year) {
	 $i++;

         my @HEADERS;
         open(QF,"<","${emaildir}/boxtrapper/queue/${queuefile}");
         while(<QF>) {
            if (/^[\r\n]*$/) {last;}
            push(@HEADERS, $_);
         }
         close(QF);

         my $email = BoxTrapper_extractfrom(BoxTrapper_getheader("from",\@HEADERS));
         my $subject = BoxTrapper_getheader("subject",\@HEADERS);


         $subject = BoxTrapper_cleanfield($subject);
         $email = BoxTrapper_cleanfield($email);

	$BXMSG{$i}{'time'} = $tt;
	$BXMSG{$i}{'queuefile'} = $queuefile;
	$BXMSG{$i}{'email'} = $email;
	$BXMSG{$i}{'subject'} = $subject;
	$BXMSG{$i}{'nicetime'} = "${qhour}:${qmin}:${qsec}";

      }
   }

   foreach my $msg (sort { $BXMSG{$a}{'time'} <=> $BXMSG{$b}{'time'} } keys %BXMSG) {
         print "<tr>";
         print "<td><a href=\"${showfile}?t=${logdate}&account=${account}&q=$BXMSG{$msg}{'queuefile'}&bxaction=${bxaction}\">$BXMSG{$msg}{'email'}</a></td>";
         print "<td><a href=\"${showfile}?t=${logdate}&account=${account}&q=$BXMSG{$msg}{'queuefile'}&bxaction=${bxaction}\">$BXMSG{$msg}{'subject'}</a></td>";
         print "<td><a href=\"${showfile}?t=${logdate}&account=${account}&q=$BXMSG{$msg}{'queuefile'}&bxaction=${bxaction}\">$BXMSG{$msg}{'nicetime'}</a></td>";
         print "</tr>";
   }
}

sub BoxTrapper_logcontrols {
   my ($logdate,$account,$bxaction) = @_;
   if ($logdate eq "") { $logdate = time(); }

   print "<td align=left>";
   my $nd = ($logdate - 86400);
   my($mon,$mday,$year) = BoxTrapper_nicedate($nd);
   print "<a href=\"/$ENV{'SCRIPT_URI'}?bxaction=${bxaction}&account=${account}&logdate=${nd}\">&lt;&lt; ${mon}-${mday}-${year}</a>";

   print "</td><td align=center>";
   my($mon,$mday,$year) = BoxTrapper_nicedate($logdate);
   print "${mon}-${mday}-${year}";

   print "</td><td align=right>";
   my $nd = ($logdate + 86400);
   my($mon,$mday,$year) = BoxTrapper_nicedate($nd);
   print "<a href=\"/$ENV{'SCRIPT_URI'}?bxaction=${bxaction}&account=${account}&logdate=${nd}\">${mon}-${mday}-${year} &gt;&gt;</a>";
   print "</td>";

}

sub BoxTrapper_cleanfield {
   my $value = $_[0];
   $value =~ s/</\&lt;/g;
   $value =~ s/>/\&gt;/g;
   $value =~ s/"/\&quot;/g;
   return $value;
}

sub BoxTrapper_showemails {
   my($account) = @_;

   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if ($emaildir eq "" || $emaildeliverdir eq "") {
      print "Email homedir for ${account} does not exist";
      return();
   }

   my %CONF = BoxTrapper_loadconf($emaildir,$account);

   print $CONF{'froms'};
}


sub BoxTrapper_showqueuetime {
   my($account) = @_;

   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if ($emaildir eq "" || $emaildeliverdir eq "") {
      print "Email homedir for ${account} does not exist";
      return();
   }

   my %CONF = BoxTrapper_loadconf($emaildir,$account);

   print $CONF{'stale-queue-time'};	

}

sub BoxTrapper_saveconf {
   my($account,$froms,$queuetime) = @_;

   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if ($emaildir eq "" || $emaildeliverdir eq "") {
      print "Email homedir for ${account} does not exist";
      return();
   }

   open(CF,">","${emaildir}/boxtrapper.conf");
   print CF "froms=${froms}\n";
   print CF "stale-queue-time=${queuetime}\n";
   close(CF);

}

sub BoxTrapper_getboxconfdir {
   my($account) = @_;

   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if ($emaildir eq "" || $emaildeliverdir eq "") {
      print "Email homedir for ${account} does not exist";
      return();
   }


   if (! -e "${emaildir}/.boxtrapper") {
      mkdir("${emaildir}/.boxtrapper",0700);
   }

   print "${emaildir}/.boxtrapper";
}


sub BoxTrapper_listmsgs {
   my($account,$editfile,$resetfile) = @_;

   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);


   opendir(FORMS,"/usr/local/cpanel/etc/boxtrapper/forms");
   my @FORMS = readdir(FORMS);
   closedir(FORMS);

   @FORMS = grep(!/^\./, @FORMS);


   foreach my $form (@FORMS) {
      $form =~ s/\.txt$//g;
      print "<tr>";
      print "<td>${form}</td>\n";
      print "<td><form action=${editfile}>";
      print "<input type=hidden name=account value=\"${account}\">";
      print "<input type=hidden name=form value=\"${form}.txt\">";
      print "<input type=hidden name=emaildir value=\"${emaildir}/.boxtrapper/forms\">";
      print "<input type=submit value=Edit></form></td>\n";
      print "<td><form action=${resetfile}>";
      print "<input type=hidden name=account value=\"${account}\">";
      print "<input type=hidden name=form value=\"${form}.txt\">";
      print "<input type=hidden name=emaildir value=\"${emaildir}/.boxtrapper/forms\">";
      print "<input type=submit value=\"Reset to default\"></form></td>\n";
      print "</tr>";
   }

}

sub BoxTrapper_editmsg {
   my($account,$message) = @_;
   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   $message =~ s/\///g;
   $message =~ s/\.\.//g;

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if (! -e "${emaildir}/.boxtrapper") {
      mkdir("${emaildir}/.boxtrapper",0700);
   }
   if (! -e "${emaildir}/.boxtrapper/forms") {
      mkdir("${emaildir}/.boxtrapper/forms",0700);
   }

   if (! -e "${emaildir}/.boxtrapper/forms/${message}") {
      system("cp","-f","/usr/local/cpanel/etc/boxtrapper/forms/${message}","${emaildir}/.boxtrapper/forms/${message}");	
   }

}

sub BoxTrapper_resetmsg {
   my($account,$message) = @_;
   my ($homedir,$domain) = BoxTrapper_getaccountinfo($account);

   $message =~ s/\///g;
   $message =~ s/\.\.//g;

   if ($homedir eq "") {
      print "Unable to locate home dir for account ${account}\n";
      return();
   }

   my ($emaildir,$emaildeliverdir) = BoxTrapper_getemaildirs($account,$homedir);

   if (-e "${emaildir}/.boxtrapper/forms/${message}") {
      unlink("${emaildir}/.boxtrapper/forms/${message}");
   }

}

