#!/bin/bash

binday_config="/etc/binday/binday.cfg"

#check that the binday config file exists.
if [ -a $binday_config ]
then
  source /etc/binday/binday.cfg
else
  echo "Please ensure $binday_config exists."
fi

#Check that the binday url is set.
if [ -z $BINDAY_URL ]
then
  echo "URL is not set, please correct this in $binday_config"
  exit
fi

#Check that the pushover details are set.
if [ -z $PUSHOVER_TOKEN ] || [ -z $PUSHOVER_USER ]
then
  echo "Your pushover API details are blank, please correct this in $binday_config"
  exit
fi

#Check if a fake tomorrow date has been set in the config, if not continue.

if [ $TOMORROW ]
then
  echo "Using fake date set in config!"
  echo "Fake date: $TOMORROW"
  tomorrow=$TOMORROW
else
  tomorrow=`date +"%-d%-m%Y" -d "tomorrow"`
  tomorrow_nice=`date +"%d/%m/%Y" -d "tomorrow"`
fi

tmpfile='/tmp/binday.tmp'

echo "$(date +"%m-%d-%Y-%T"): Starting bin run"

#Pull down local news into tmp
wget -q -O $tmpfile "$BINDAY_URL"

#Check contents of file, if not valid then error

if [ -e $tmpfile ]
then
  hasdata=`grep -E '(Household waste bin|Mixed recycling bin|Garden waste recycling bin)' $tmpfile`
  if [ -z "$hasdata" ]
  then
    echo "Cant find data yo."
    exit
  fi
else
  echo "no file bro"
  exit
fi

#scrape and store next bin collection dates

#Household waste bin
housenext=`grep "Household waste bin" $tmpfile | awk -F "next collection will be on" '{ print $2 }'| awk  -F "." '{ print $1 }' | sed -e 's/\///g' -e 's/ //g'`
#Mixed recycling box
mixednext=`grep "Mixed recycling bin" $tmpfile | awk -F "next collection will be on" '{ print $2 }'| awk  -F "." '{ print $1 }' | sed -e 's/\///g' -e 's/ //g'`
#Garden waste recycling bin
gardennext=`grep "Garden waste recycling bin" $tmpfile | awk -F "next collection will be on" '{ print $2 }'| awk  -F "." '{ print $1 }' | sed -e 's/\///g' -e 's/ //g'`

#Compare dates and send notification if the bin needs putting out tonight.
output="Tomorrows Date: $tomorrow_nice\n\n"
echo "---Data---"
echo "Tomorrows Date: $tomorrow"
echo "Household Collection: $housenext"
echo "Mixed Recycle Collection: $mixednext"
echo "Garden Collection: $gardennext"
echo "---END DATA---"

#Household waste bin
if [ -n "$housenext" ]
then
  if [ "$tomorrow" -eq "$housenext" ]
  then
    output="$output Put the fucking household waste bin out. (Big Green One)\n\n"
    sendnotif=1
  fi
fi

#Mixed recycling box
if [ -n "$mixednext" ]
then
  if [ "$tomorrow" -eq "$mixednext" ]
  then
    output="$output Put the fucking mixed recycling bin out. (Brown One without holes)\n\n"
    sendnotif=1
  fi
fi

#Garden waste recycling bin
if [ -n "$gardennext" ]
then
  if [ "$tomorrow" -eq "$gardennext" ]
  then
    output="$output Put the fucking Garden waste recycling bin out. (Big brown one with holes.)\n\n"
    sendnotif=1
  fi
fi

#Time to push

if [[ $sendnotif -eq 1 ]]
then
  echo -e $output
  echo "Sending Notification"
  curl -s \
    --form-string "token=$PUSHOVER_TOKEN" \
    --form-string "user=$PUSHOVER_USER" \
    --form-string "message=$(echo -e $output)" \
    https://api.pushover.net/1/messages.json
fi

echo "$(date +"%m-%d-%Y-%T"): Ending bin run"

rm -f $tmpfile
