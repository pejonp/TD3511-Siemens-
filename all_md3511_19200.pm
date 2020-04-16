#!/usr/bin/perl 

#
# (m)ein Stromzähler mit IR-Schnittstelle blubbert nach einem "Anforderung-
# telegramm" Daten raus. Das Telegramm ist mit 300 Baud, 7 Bit, 1 Stoppbit
# und gerader Parität zu senden. Das ist der Initialmodus von Geräten,
# die das Protokoll IEC 62056-21 implementieren.
#
# Autor: Andreas Schulze
# Bugfix: Eric Schanze
# Datum: 20120302
#

use POSIX qw(strftime);
my $now =strftime "%Y_%m_%d_%H_%M_%S", localtime;

my $dateiname = ">>values".@now. ".txt";
my $PORT='/dev/lesekopf0';
my $anforderungstelegramm = "\n/?!\r\n";

#  "pullseq" : "2F3F210D0A",  # Pullsequenz in 'hex' 
#  "ackseq": "063030300d0a",  # Antwortsequenz auf Zählerantwort,063030300d0a = 300bd, 063035300d0a = 9600bd   
# fuer 9600
#my $out0 = "\x06\x30\x35\x31\x0D\x0A";
#my $out0 = "\x06050\r\n";

# fuer 19200:
my $out0 = "\x06060\r\n";

use warnings;
use strict;
use utf8;
use Device::SerialPort;

my $merk;
my ($num_read, $s);
my $exit=0;
#my $dfile1 = ">>values2808.txt";      # Datei zum anhängenden Schreiben öffnen
my $dfile1 = $dateiname;      # Datei zum anhängenden Schreiben öffnen

open FILE, $dfile1  or die "can't open $dfile1: $!";
 # Autoflush
select FILE;
$| = 1;

my $tty = new Device::SerialPort($PORT) || die "can't open $PORT: $!";
$tty->baudrate(300)      || die 'fail setting baudrate';
$tty->databits(7)        || die 'fail setting databits';
$tty->stopbits(1)        || die 'fail setting stopbits';
$tty->parity("even")     || die 'fail setting parity';
#$tty->handshake ("none") || die "fail setting handshake";
$tty->write_settings     || die 'fail write settings';
#$tty->debug(1);
$tty->read_const_time(1);

my $num_out = $tty->write($anforderungstelegramm);
die "write failed\n" unless ($num_out);
die "write inclomplete\n" unless ($num_out == length($anforderungstelegramm));
#print "$num_out Bytes written\n";

while(1) {
  ($num_read, $s) = $tty->read(1);
     if ($s eq "\n")
   {
   # print "$merk","\n";
    print FILE "$merk","\n";
    $merk = "";
    last;
   }
   else
   {
   $merk = $merk.$s;
    }
  }

$num_out = $tty->write($out0);
die "write failed\n" unless ($num_out);
die "write inclomplete\n" unless ($num_out == length($out0));
#print "$num_out Bytes written\n";

#print $exit,"\n"; 
#while($exit < 420000) {
#      $exit++;
#}
#print $exit,"\n"; 

### Warte auf Zaehlerkennung
select(undef, undef, undef, 0.3); # 1.5 Sekunden warten


$tty->baudrate (19200);
#$tty->baudrate (9600);
$tty->write_settings     || die 'fail write settings';

$tty->read_const_time(10);
while(1) {
  ($num_read, $s) = $tty->read(1);
  if ($s eq "!")
  {
   print FILE "$s","\n";
  last;
  }
  else{
    if ($s eq "\n")
   {
    print FILE "$merk","\n";
    $merk = "";
   }
   else
   {
   $merk = $merk.$s;
    }
  }
  }
    
$tty->close || die "can't close $PORT: $!";
 close FILE;