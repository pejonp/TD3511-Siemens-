#!/usr/bin/perl

##############################################
# $Id: 00_TD3511.pm 1001 2016-10-28 10:10:10Z pejonp $
#
# (m)ein Stromzähler mit IR-Schnittstelle blubbert nach einem "Anforderung-
# telegramm" Daten raus. Das Telegramm ist mit 300 Baud, 7 Bit, 1 Stoppbit
# und gerader Parität zu senden. Das ist der Initialmodus von Geräten,
# die das Protokoll IEC 62056-21 implementieren.
#
# Autor: Andreas Schulze
# Datum: 20120321
#
# 28.08.2016 J.Köhn pejonp
#
use DBI;
use warnings;
use strict;
use Device::SerialPort;
use Time::HiRes qw(usleep nanosleep);
#use Time::HiRes;

#use vars qw($zaehler); 
  
my $PORT='/dev/lesekopf0';
my $lf = "\n";
my $AufforderungsTelegramm = "\n/?!\r\n";
#$| = 1;

my $DEVICE_VORBELEGUNG = "TD3511";
my $TYPE_VORBELEGUNG = "ZAEHLER";

my $db_host = '192.xxx.x.xxx';
my $db_port = 3306;
my ($db_user, $db_name, $db_pass) = ('fhem', 'fhem', 'passwd');
my $OptionsAuswahlTelegramm = "\x06060\r\n";
my $debug = 0;

my $tty;
my ($bytes_sent, $bytes_read2, $s2, $answer);
#my ($num_read, $s);
my $s;
my $merk;
my $zaehler = 0;

use warnings;
use strict;
use utf8;
use Device::SerialPort;
#use Data::Hexdumper qw(hexdump);
use POSIX qw(strftime);
my $now =strftime "%Y-%m-%d %H:%M:%S", localtime;
my $now1 =strftime "%Y-%m-%d_%H:%M:%S", localtime;



### KONFIGURATION ###
my %channels = ( #Obis-Zahl => Gruppenadresse
                "F.F"=>"F-F",
	       	"1.7.0"=>"1-7-0",    #Leistung
                "2.7.0"=>"2-7-0",    #Einspeiseleistung
                #"2.8.0"=>"2-8-0",
                "1.8.0"=>"1-8-0",    #Zählerstand gesamt
                "1.8.1"=>"1-8-1",    #Aktueller Zählerstand Tag
                "1.8.2"=>"1-8-2",    #Aktueller Zählerstand Nacht
                "2.8.6"=>"2-8-6",    #Aktueller Zählerstand Rücklieferung
                "14.7"=>"14-7",      #Frequenz
                "31.7"=>"31-7",      #Strom_L1
                "51.7"=>"51-7",      #Strom_L2
                "71.7"=>"71-7",      #Strom_L3
                "91.7"=>"91-7",      #Strom_Neutral
                "32.7"=>"32-7",      #Spannung_V1
                "52.7"=>"52-7",      #Spannung_V2
                "72.7"=>"72-7",      #Spannung_V3
               );     
### ENDE KONFIGURATION ###

sub ir_send($) {

  my ($tosend) = @_;

 # print hexdump($tosend) if (defined $debug);
  $bytes_sent = $tty->write($tosend);
  die "write failed\n" unless ($bytes_sent);
  die "write inclomplete\n" unless ($bytes_sent == length($tosend));
#  print "$bytes_sent Bytes written\n" if (defined $debug);
  $bytes_sent;
}

sub ir_read() {

  my $line;

  do {
    ($bytes_read2, $s2) = $tty->read(1);
    $line .= $s2
  } until ($s2 eq $lf);

  $line;
}

sub opentty($;$) {

  my ($baudrate) = @_;

  my $t = new Device::SerialPort($PORT) || die "can't open $PORT: $!";
  $t->baudrate($baudrate) || die 'fail setting baudrate';
  $t->databits(7)         || die 'fail setting databits';
  $t->stopbits(1)         || die 'fail setting stopbits';
  $t->parity("even")      || die 'fail setting parity';
  $t->write_settings      || die 'fail write settings';
  $t->read_const_time(10);
 # $t->debug(1) if (defined $debug);

  $t;
}


my $dbh = DBI->connect("DBI:mysql:database=$db_name;host=$db_host;port=$db_port","$db_user", "$db_pass");



$tty = opentty(300);

#print "Open Port 300 baud \n";

# ein Dummy Byte senden, um die IR-Schnittstelle auf 300 Baud zu schalten
ir_send($lf);

ir_send($AufforderungsTelegramm);
$answer = ir_read();
#print $answer;

ir_send($OptionsAuswahlTelegramm);

#print "umschalten auf 19200 baud \n";

# Sleep for 250 milliseconds 0.25
select(undef, undef, undef, 0.2);

$tty->close || die "can't close $PORT: $!";
$tty = opentty(19200);
#print "\n";

do {
  $s = ir_read();
#  print $s;
   if ($s eq "!") {
     last;
   }else {
      my @buffer = $s;
      foreach (@buffer)
      {
        foreach my $obis(%channels)
          {
            my $obiskey = $obis."\(";
            if ($_ =~ /^\Q$obiskey\E/)       
              {
                $_  =~ m/[^(]+\(([^*]+)\*([^)]+)/;
                my $TIMESTAMP = $now;
                my $DEVICE = $DEVICE_VORBELEGUNG;
                my $TYPE = $TYPE_VORBELEGUNG;
                my $gg = $channels{$obis};
                my $EVENT = $gg.": ".$1." ".$2;
                my $READING = $gg;
                my $VALUE = $1;
                my $UNIT = $2;
                # TIMESTAMP, DEVICE , TYPE , EVENT , READING , VALUE , UNIT 
                print "$TIMESTAMP | $DEVICE | $TYPE | $EVENT | $READING | $VALUE | $UNIT \n";
                #print "$now1 TD3511 $gg $VALUE $UNIT\n";
                # 'current' (TIMESTAMP, DEVICE , TYPE , EVENT , READING , VALUE , UNIT ); 
                $dbh->do("INSERT INTO history VALUES (?, ?, ?, ?, ?, ?, ?)", undef, $TIMESTAMP , $DEVICE, $TYPE,$EVENT,$READING,$VALUE,$UNIT );
                # beiden Tabellen füllen vorher in current löschen
                if ($zaehler == 0 ) {         
                    # da mehrere Datensätze -> Merker setzten, das nicht wieder die neuen gelöscht werden
                    # update der Tabelle hat nich so funktioniert
                    $dbh->do("delete from  current WHERE DEVICE='$DEVICE'") || die "delete: $DBI::errstr \n";
                    $zaehler = 1;
                }
                $dbh->do("INSERT INTO current VALUES (?, ?, ?, ?, ?, ?, ?)", undef, $TIMESTAMP , $DEVICE, $TYPE,$EVENT,$READING,$VALUE,$UNIT );
           }
        }
     }
   }
} until ($s eq "!\r\n");

$zaehler = 0;

$tty->close || die "can't close $PORT: $!";

