#!/usr/bin/perl
# Derlenmis siteyi bu bilgisayarda gosteren kucuk sunucu (yalnizca bu bilgisayardan erisilir).
# Kullanim: perl sunucu.pl [site klasoru] [port]
# Klasor verilmezse: yaninda site/ klasoru varsa onu, yoksa bir ust klasoru (indirilen derlemenin kendisi) acar.
use strict;
use warnings;
use IO::Socket::INET;

use File::Basename qw(dirname);
use Cwd qw(abs_path);
my $kok  = shift;
if (!defined $kok || $kok eq '') {
  my $ust = dirname(dirname(abs_path($0)));
  $kok = -f "$ust/site/index.html" ? "$ust/site" : $ust;
}
my $port = shift // 8765;
$kok =~ s{/+$}{};

my $dinle;
for my $p ($port .. $port + 20) {
  $dinle = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $p, Listen => 32, ReuseAddr => 1, Proto => 'tcp');
  if ($dinle) { $port = $p; last }
}
die "Bos port bulunamadi\n" unless $dinle;

my %tur = (
  html => 'text/html; charset=utf-8', js => 'text/javascript; charset=utf-8', mjs => 'text/javascript; charset=utf-8',
  css => 'text/css; charset=utf-8', json => 'application/json', svg => 'image/svg+xml', png => 'image/png',
  jpg => 'image/jpeg', jpeg => 'image/jpeg', webp => 'image/webp', avif => 'image/avif', gif => 'image/gif',
  ico => 'image/x-icon', glb => 'model/gltf-binary', mp4 => 'video/mp4', webm => 'video/webm',
  woff2 => 'font/woff2', woff => 'font/woff', xml => 'application/xml', txt => 'text/plain; charset=utf-8',
);

my $adres = "http://localhost:$port/";
print "\nSite acildi: $adres\nKapatmak icin bu pencereyi kapatin.\n\n";
if (($ENV{SITE_AC} // '') eq '1') { system($^O eq 'darwin' ? 'open' : 'xdg-open', $adres) }

$| = 1;
$SIG{CHLD} = 'IGNORE';
while (1) {
  my $c = $dinle->accept or next;
  my $pid = fork;
  if (!defined $pid || $pid) { close $c; next }
  close $dinle;
  $SIG{ALRM} = sub { exit 0 };
  alarm 60;
  binmode $c;
  my $istek = <$c>;
  exit 0 unless defined $istek;
  while (my $satir = <$c>) { last if $satir =~ /^\r?\n$/ }
  my ($yontem, $yol) = $istek =~ m{^(\w+)\s+(\S+)};
  $yontem //= 'GET';
  $yol //= '/';
  $yol =~ s/[?#].*//;
  $yol =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
  my $yanit = sub {
    my ($kod, $ek, $govde) = @_;
    print $c "HTTP/1.1 $kod\r\n$ek" . 'Content-Length: ' . length($govde) . "\r\nConnection: close\r\n\r\n";
    print $c $govde if $yontem ne 'HEAD';
  };
  if ($yol =~ m{(^|/)\.\.(/|$)}) { $yanit->('403 Forbidden', '', 'Yasak'); exit 0 }
  my $dosya = "$kok$yol";
  if (-d $dosya) {
    if ($yol !~ m{/$}) { $yanit->('301 Moved Permanently', "Location: $yol/\r\n", ''); exit 0 }
    $dosya .= 'index.html';
  }
  my $kod = '200 OK';
  unless (-f $dosya) { $dosya = "$kok/404.html"; $kod = '404 Not Found' }
  if (open my $f, '<:raw', $dosya) {
    my ($uzanti) = $dosya =~ /\.([^.\/]+)$/;
    my $t = $tur{lc($uzanti // '')} // 'application/octet-stream';
    my $boy = -s $dosya;
    print $c "HTTP/1.1 $kod\r\nContent-Type: $t\r\nContent-Length: $boy\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n";
    if ($yontem ne 'HEAD') { my $tampon; while (read($f, $tampon, 65536)) { print $c $tampon } }
    close $f;
  } else {
    $yanit->('404 Not Found', "Content-Type: text/plain; charset=utf-8\r\n", 'Bulunamadi');
  }
  close $c;
  exit 0;
}
