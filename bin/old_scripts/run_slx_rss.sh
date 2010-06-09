#!/bin/sh
#
# $Id: run_slx_rss.sh 495 2008-04-18 15:51:48Z dc12 $
#

find /data/slx/goats -follow -name "Summary.htm" > /data/slx/USI-EAS09/webs/prod-solexa/htdocs/goats.txt 2>/dev/null 
mv /data/slx/USI-EAS09/webs/prod-solexa/htdocs/goats.txt /data/slx/USI-EAS09/webs/prod-solexa/htdocs/goats/goats.txt
sleep 5
ruby /users/sol-pipe/.drio/src/solexa_rss/slx_rss.rb
mv /users/sol-pipe/.drio/src/solexa_rss/solexa-rss.tmp.xml /data/slx/USI-EAS09/webs/prod-solexa/htdocs/rss/solexa-rss.xml

ruby /users/sol-pipe/.drio/src/solexa_rss/slx_csv.rb
cp /users/sol-pipe/.drio/src/solexa_rss/slx_data.current.tmp.csv /data/slx/USI-EAS09/webs/prod-solexa/htdocs/csv/solexa_data.current.csv

ruby /users/sol-pipe/.drio/src/solexa_rss/slx_all_csv.rb
cp /users/sol-pipe/.drio/src/solexa_rss/slx_data.all.tmp.csv /data/slx/USI-EAS09/webs/prod-solexa/htdocs/csv/solexa_data.all.csv
