#!/usr/bin/perl
# cpanelpro - ImageManager.pm             Copyright(c) 1999-2003 John N. Koston
#                                 All rights Reserved.
# bdraco@darkorb.net              http://cpanel.net

package Cpanel::ImageManager;

use strict;
use Carp;

use vars qw(@ISA @EXPORT $VERSION);

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(ImageManager_init ImageManager_dimensions ImageManager_hdimension ImageManager_wdimension ImageManager_scale ImageManager_thumbnail ImageManager_convert);

$VERSION = '1.0';

require 5.004;


sub ImageManager_init {
   return(1);
}

sub ImageManager_dimensions {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my($dir,$file,$re) = @_;

   open(IDENTIFY,"-|") || exec ("identify","${dir}/${file}");
   while(<IDENTIFY>) { 
      if (/(\d+x\d+)/) { 
         if ($re) { close(IDENTIFY); return($1); }
         print "$1"; 
      } else { 
         print "Unable to process image"; 
      }
      last;
   }
   close(IDENTIFY);
}

sub ImageManager_scale {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my($dir,$file,$oldimage,$width,$height,$keepold) = @_;

   if (! -f "${dir}/${file}") {
      print "The file does not exist ${dir}/${file}!\n";
      return();
   }
   system("convert","-size","${width}x${height}","${dir}/${file}","-resize","${width}x${height}","${dir}/${file}.cPscale");
   if ($keepold) {
      system("mv","-f","${dir}/${file}","${oldimage}");
   }
   system("mv","-f","${dir}/${file}.cPscale","${dir}/${file}");
}

sub _convert {
   my($oldfile,$newtype) = @_;

   my $newfile = $oldfile;

   return if ($newfile =~ /\.${newtype}/);

   $newfile =~ s/\.?[^\.]+$//g;

   if ($newfile eq "") { $newfile = $oldfile; }

   $newfile .= "\.${newtype}";

   print "Converting ${oldfile} to ${newfile}.......";
   system("convert","${oldfile}","${newfile}");
   if (! -e ${newfile}) {
      print "....Failed (not a valid image file)!<br>";
   } else {
      print "....Done<br>";
   }

}

sub ImageManager_thumbnail {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my($dir,$wperc,$hperc) = @_;

   $wperc = ($wperc / 100);
   $hperc = ($hperc / 100);

   if (! -d "${dir}") {
      print "The directory does not exist ${dir}!\n";
      return();
   }
   if (! -d "${dir}/thumbnails") {
      mkdir("${dir}/thumbnails",0755);
   }


   opendir(DIR,$dir);
   my @FILES=readdir(DIR);
   closedir(DIR);

   foreach my $file (@FILES) {
      next if ($file =~ /^\./);
      my $dims = ImageManager_dimensions(${dir},${file},1);
      if ($dims ne "") {
         $dims =~ /(\d+)x(\d+)/;
         my $width = ($1 * $wperc);
         my $height = ($2 * $hperc);
         print "Thumbnailing...${dir}/${file} (${1}x${2})...";
         system("convert","-size","${width}x${height}","${dir}/${file}","-resize","${width}x${height}","${dir}/thumbnails/tn_${file}");
         print "wrote...${dir}/thumbnails/tn_${file} (${width}x${height})...Done\n<br>";
      }
   }	
}

sub ImageManager_convert {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my($target,$newtype) = @_;

   if (-d "${target}") {
      opendir(DIR,$target);
      my @FILES=readdir(DIR);
      closedir(DIR);
      foreach my $file (@FILES) {
         my $prevfile = "${target}/${file}";
         next if (! -f $prevfile);
         _convert($prevfile,$newtype);
      }
   } else {
      _convert($target,$newtype);
   }
}

sub ImageManager_hdimension {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my($dir,$file) = @_;

   my $h;

   open(IDENTIFY,"-|") || exec ("identify","${dir}/${file}");
   while(<IDENTIFY>) { if (/\d+x(\d+)/) { $h = $1; }; last; }
   close(IDENTIFY);

   print "$h";
}

sub ImageManager_wdimension {
   if ($Cpanel::flags !~ /pro/i) {
      print "Sorry, this copy of cPanel Pro is missing the license file!\n";
      return();
   }

   my($dir,$file) = @_;

   my $w;

   open(IDENTIFY,"-|") || exec ("identify","${dir}/${file}");
   while(<IDENTIFY>) { if (/(\d+)x\d+/) { $w = $1; }; last; }
   close(IDENTIFY);

   print "$w";
}

