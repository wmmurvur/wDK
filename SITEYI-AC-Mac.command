#!/bin/bash
# Cift tiklayin: site bu bilgisayarda acilir ve tarayici kendiliginden gelir. Kapatmak icin Terminal penceresini kapatin.
cd "$(dirname "$0")" || exit 1
if [ -x /usr/bin/perl ]; then
  SITE_AC=1 exec /usr/bin/perl "_yerel-sunucu/sunucu.pl" "" 8765
fi
# perl yoksa python3 ile
KOK="$PWD"; [ -f site/index.html ] && KOK="$PWD/site"
(sleep 1; open "http://localhost:8765/") &
cd "$KOK" && exec python3 -m http.server 8765 --bind 127.0.0.1
