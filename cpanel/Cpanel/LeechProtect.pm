#!/usr/bin/perl
# cpanelpro - LeechProtect.pm             Copyright(c) 1999-2003 John N. Koston
#                                 All rights Reserved.
# bdraco@darkorb.net              http://cpanel.net

package Cpanel::LeechProtect;

use strict;
use Carp;

use vars qw(@ISA @EXPORT $VERSION);

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(LeechProtect_enable LeechProtect_disable LeechProtect_status LeechProtect_setup LeechProtect_showpasswdfile LeechProtect_init);
$VERSION = '1.0';

require 5.004;

sub LeechProtect_init {
	return(1);
}


sub LeechProtect_setup {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my($dir,$item,$type) = @_;

   $dir =~ s/\.\.//g;
   $dir = Cpanel::FileMan::makecleandir($dir);

   open(LPC,"<","${dir}/.leechprotect-conf");
   while(<LPC>) {
      chomp();
      if (/^${item}=(\S*)/) {
         close(LPC);
         if ($type eq "checkbox") {
            if ($1 eq "1" || $1 ne "") {
               print "checked";
            }
            return();
         } else {
            print "$1";
            return();
         }
      }
   }
   close(LPC);


}


sub LeechProtect_init {
   return(1);
}

sub LeechProtect_status {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my ($dir) = @_;
   $dir =~ s/\.\.//g;
   $dir = Cpanel::FileMan::makecleandir($dir);

   open(HC,"<","${dir}/.htaccess");
   while(<HC>) {
      if (/LeechProtect/) { print "enabled"; return(); }
   }
   close(HC);	
   print "disabled";
}

sub LeechProtect_enable {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   if ($Cpanel::CPDATA{'DEMO'} eq "1") {
      print "Sorry this feature is disabled in demo mode";
      return();
   }

   my ($dir,$numhits,$badurl,$email,$killcompro) = @_;

   $numhits=int($numhits);
   if ($numhits < 1) { $numhits = 4; }

   my($hasrengine) = 0;
   my($skipline) = 0;
   my(@HC);
   
   $dir =~ s/\.\.//g;
   $dir = Cpanel::Fileman::makecleandir($dir);
   
   open(LPC,">","${dir}/.leechprotect-conf");
   print LPC "email=${email}\n";
   print LPC "kill=${killcompro}\n";
   print LPC "url=${badurl}\n";
   print LPC "numhits=${numhits}\n";
   close(LPC);


   open(HC,"<","${dir}/.htaccess");
   while(<HC>) {
      push(@HC,$_);
      if (/^[\s\t]*RewriteEngine on/i) { $hasrengine = 1; }
   }
   close(HC);

   open(HC,">","${dir}/.htaccess") || print "<b>Error: while opening htaccess</b>\n";

   if (!${hasrengine}) {
      print HC "\nRewriteEngine on\n";
   }
   foreach (@HC) {
      if ($skipline)  { $skipline = 0; next; }
      if (/LeechProtect/) { $skipline = 1; next; }
      print HC;
   }

   print HC "\n" . 'RewriteCond ${LeechProtect:' . ${dir} .
   ':%{REMOTE_USER}:%{REMOTE_ADDR}:' . ${numhits} . "} leech\n";
   print HC "RewriteRule .* ${badurl}\n";
   close(HC);


}

sub LeechProtect_disable {
   if ($Cpanel::CPDATA{'DEMO'} eq "1") {
      print "Sorry this feature is disabled in demo mode";
      return();
   }

   my ($dir) = @_;
   $dir =~ s/\.\.//g;
   $dir = Cpanel::Fileman::makecleandir($dir);
   
   
   
   my($hasrengine) = 0;
   my($hasr) = 0; #has other rewrite rules
   my($skipline) = 0;
   my(@HC);

   open(HC,"<","${dir}/.htaccess");
   while(<HC>) {
      if ($skipline)  { $skipline = 0; next; }
      if (/LeechProtect/) { $skipline = 1; next; }
      push(@HC,$_);
      if (/^[\s\t]*RewriteEngine on/i) { $hasrengine = 1; }
      elsif (/^[\s\t]*Rewrite/i) { $hasr = 1; }
   }
   close(HC);

   open(HC,">","${dir}/.htaccess") || print "<b>Error: while opening htaccess</b>\n";
   foreach (@HC) {
      if (/^[\s\t]*RewriteEngine on/i && (!$hasr)) { next; }
      print HC;
   }
   close(HC);
}

sub LeechProtect_showpasswdfile {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my($dir) =  @_;
   my($lang) = $Cpanel::CPDATA{'LANG'};
   my($tdir);
   $dir =~ s/^$Cpanel::homedir\/public_html//g;
   $dir =~ s/^\/public_html\/$//g;
   $dir =~ s/\.\.//g;
   $dir =~ s/^\///g;
   $dir = "$Cpanel::homedir/public_html/$dir";
   if (! -e "$dir") {
      print "$Cpanel::Lang::LANG{$lang}{'cpanel-findfolder'} [$dir]\n";
      exit;
   }
   chdir("$dir");
   $dir =~ s/\/$//g;
   $tdir = $dir;
   $tdir =~ s/^$Cpanel::homedir//g;
   $tdir =~ s/^\/public_html//g;
   $tdir =~ s/^\///g;
   $tdir =~ s/\.\.//g;
   $tdir =~ s/^\///g;


   print "$Cpanel::homedir/.htpasswds/$tdir/passwd";
}



1;
