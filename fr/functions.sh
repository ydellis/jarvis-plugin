#!/bin/bash
#Version 2.0
gare_depart="Blanmont"
gare_destination="Bruxelles"
destination="$gare_destination"

jv-get-station() {
local __myresult=$1
local dest=$(echo $destination)
nbmots=`echo $dest | wc -w`
a=( $dest )
local json_stations=$(curl -s -S -H "accept: application/json" https://irail.be/stations/NMBS) 
local lg=$(echo "${#json_stations}")
local json_stations_cor="$(echo "$json_stations"  | tr -d '[=@=]')"
local lg1=$(echo "${#json_stations_cor}")
local stations=$(echo "$json_stations_cor" | jq '[.graph[].name,.alternative.value]' | sed 's/\[//' | sed 's/\]//')
local sta="$(echo -e "${stations}" | tr -d '[="=]' | sed s/' '/'_'/g)" 
local prefix="__"
IFS=',' read -a stat <<< $sta
local nmax="${#a[@]}"
local stmax="${#stat[@]}"
for (( n=0; n < ${nmax}; n++ ))
do
   for (( st=0; st < ${stmax}; st++ ))
   do
      local tx=${stat[$st]:3}
#      echo "n= $n , st= $st, tx =${tx},${stat[$st]}, a =${a[$n]}, stmax= ${stmax}"
      if  echo "$tx" | grep -i -q  "${a[$n]}" ; then
#          echo "yes destination ${a[$n]} exists"
          local myresult=$tx
          break
      fi
   done
   if (( $st >= $stmax )); then
#      echo "NO destination ${a[$n]} n'existe pas"
      local myresult="faux"
   fi
done
eval $__myresult="'$myresult'"
return
}
##############################################################################

jv_pg_cb_timetable() {
if (( $# == 0 )); then
#   echo "pas de destination précisée"
   local destinat=$(echo "$gare_destination"  | sed s/'_'/'-'/g)
else
#   local a1="Vers Bruxelles"
   local destinat=$(echo $1 | sed s/'_'/'-'/g)                  #"$(jv_sanitize "$a1")"
# trouve le dernier mot qui est supposé être la destination
   local mt=( $destinat )
   destinat=$(echo ${mt[-1] | sed s/'_'/'-'/g})
fi
echo "vers $destinat"
destination=$(echo "$destinat"  | sed s/' '/'_'/g)

jv-get-station station   # verification si la destination existe 

# echo "résultat = $station"
if [[ "$station" == "faux" ]]; then
   echo "désolé, je ne trouve pas la gare $destination"
   exit
fi
if [[ "$station" != "$destination" ]]; then
    echo "la destination est $station .."
fi
local dt=$(echo `date +%d%m%y`)
local tm=$(echo `date +%H%M`)
local cpt=0
local lg=0
while [ $cpt -lt 3 ]
do
   local json=$(curl -s -S "https://api.irail.be/connections/?to="$destination"&from="$gare_depart"&date="$dt"&time="$tm"&timeSel=depart&format=json")
   local lg=$(echo "${#json}")
#   echo "lg = $lg"
#   echo $json
   if (( "$lg" > "1000" ))
   then
      local conn0=$(echo "$json" | jq '[.connection[].departure.time]' | sed 's/\[//' | sed 's/\]//')
      local delay0=$(echo "$json" | jq '[.connection[].departure.delay]' | sed 's/\[//' | sed 's/\]//')
      local cancel0=$(echo "$json" | jq '[.connection[].departure.canceled]' | sed 's/\[//' | sed 's/\]//')
      local direct0=$(echo "$json" | jq '[.connection[].departure.direction.name]' | sed 's/\[//' | sed 's/\]//')
      break
   fi  
   cpt=$[$cpt+1]
##  echo "json = $json"
done
local connections="$(echo -e "${conn0}" | tr -d '[:space:]' | tr -d '[="=]')" 
local delays="$(echo -e "${delay0}" | tr -d '[:space:]' | tr -d '[="=]')"
local cancels="$(echo -e "${cancel0}" | tr -d '[:space:]' | tr -d '[="=]')"
local directs="$(echo -e "${direct0}" | tr -d '[:space:]' | tr -d '[="=]')"
# echo $connections
# echo $delays
IFS=',' read -a conn <<< $connections
IFS=',' read -a dela <<< $delays
IFS=',' read -a canc <<< $cancels
IFS=',' read -a dire <<< $directs
# local nb=$(echo ${#conn[@]})
local cpt=0
for n in ${!conn[*]}
do
   echo `date --date="@${conn[$n]}" +%R`
   echo ". en direction de ${dire[$n]}"
   if (( ${canc[$n]} == "0" )); then
      if (( ${dela[$n]} == "0" )); then
         echo ". pas de retard annoncé" 
      else
         echo ". avec un retard annoncé de $((${dela[$n]}/60)) minutes" 
      fi 
   else   
      echo ". attention . ce train est supprimé" 
   fi
   cpt=$[$cpt+1]
   if (( "$cpt" > "2" ))
   then
      break
   fi
   echo ". ensuite ."
done
}

 jv_pg_cb_timetable
