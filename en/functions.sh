#!/bin/bash
# Version 2.2

#jv_pg_sncb_destination="$jv_pg_sncb_gare_destination"
jv_pg_sncb_nodestin="no destination specified"
jv_pg_sncb_to="to"
jv_pg_sncb_sorry="sorry, I don't find the station"
jv_pg_sncb_direction="in the direction of"
jv_pg_sncb_nodelay="no delay announced"
jv_pg_sncb_delay="with an announced delay of"
jv_pg_sncb_warning="Warning"
jv_pg_sncb_deleted="this train is deleted"
jv_pg_sncb_then="then"
jv_pg_sncb_arrival="arrival foreseen at"

#########################################

# fonctions pour vérifier l'existance de la gare dans le fichier de la sncb et prendre la bonne syntaxe
jv_pg_sncb_get_station() {
local __myresult=$1
local dest=$(echo $jv_pg_sncb_destination)
#nbmots=`echo $dest | wc -w`
local a=( $dest )
local json_stations=$(curl -s -S -H "accept: application/json" https://irail.be/stations/NMBS)
local json_stations="$(echo "$json_stations"  | tr -d '[=@=]')"
local stations=$(echo "$json_stations" | jq '[.graph[].name,.alternative.value]' | sed 's/\[//' | sed 's/\]//' | sed 's/^[ ]*//' | tr -d '[="=]')
#echo $stations
IFS=',' read -a statweb <<< $stations
local sta="$(echo -e "${stations}"  | tr -d '[= =]'  | tr -d '[=-=]'  | iconv -f utf8 -t ascii//TRANSLIT)"
#echo $sta 
IFS=',' read -a stat <<< $sta
local nmax="${#a[@]}"
local stmax="${#stat[@]}"
#echo "nmax=$nmax, stmax=$stmax"
for (( n=0; n < ${nmax}; n++ ))
do
   for (( st=0; st < ${stmax}; st++ ))
   do
      local tx=${stat[$st]}
      local txweb=$(echo "${statweb[$st]}" | sed 's/^[ ]*//')
#      echo "n= $n , st= $st, tx = ${tx}, txweb = ${txweb}"
      if  echo "$tx" | grep -i -q  "${a[$n]}" ; then
#          echo "yes destination ${a[$n]} ($txweb) exists"
          local myresult=$txweb
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

# fonction principale pour la recherche des données sncb actuelles 
jv_pg_sncb_timetable() {
# echo "$#"
if [ -z "$1" ]; then
   echo "$jv_pg_sncb_nodestin ."
   local destinat=$(echo "$jv_pg_sncb_gare_destination"  | sed s/'_'/'-'/g)
else
   local destinat=$(echo "$1" | sed s/'_'/'-'/g)                  #"$(jv_sanitize "$a1")"
#  trouve le dernier mot qui est supposé être la destination
   local mt=( $destinat )
   destinat=$(echo ${mt[-1]})
fi
echo "$jv_pg_sncb_to $destinat ."
local destin=$(echo "$destinat"  | sed s/' '/'_'/g)
jv_pg_sncb_destination=$(echo $destin | iconv -f utf8 -t ascii//TRANSLIT)
jv_pg_sncb_destination="$(jv_sanitize "$destin")"
jv_pg_sncb_get_station jv_pg_sncb_station   # verification si la destination existe 

# echo "résultat = $jv_pg_sncb_station"
if [[ "$jv_pg_sncb_station" == "faux" ]]; then
   echo "$jv_pg_sncb_sorry $jv_pg_sncb_destination"
   exit
fi
jv_pg_sncb_destination=$jv_pg_sncb_station
local webdepart=${jv_pg_sncb_gare_depart// /'%20'}
local webdestination=${jv_pg_sncb_station// /'%20'}
#echo $webdepart
#echo $webdestination
local dt=$(echo `date +%d%m%y`)
local tm=$(echo `date +%H%M`)
local lg=0
local cpt=0
while [ $cpt -lt 3 ]
do
# echo "$jv_pg_sncb_gare_depart  -->  $jv_pg_sncb_destination"
   local json=$(curl -s -S "https://api.irail.be/connections/?to="$webdestination"&from="$webdepart"&date="$dt"&time="$tm"&timeSel=depart&format=json")
#   local json=$(curl -s -S "https://api.irail.be/connections/?to=Bruxelles-Nord&from=Blanmont&date="$dt"&time="$tm"&timeSel=depart&format=json")
   local lg=$(echo "${#json}")
#   echo "lg = $lg"
#   echo $json
   if (( "$lg" > "1000" ))
   then
      local conn0=$(echo "$json" | jq '[.connection[].departure.time]' | sed 's/\[//' | sed 's/\]//')
      local delay0=$(echo "$json" | jq '[.connection[].departure.delay]' | sed 's/\[//' | sed 's/\]//')
      local cancel0=$(echo "$json" | jq '[.connection[].departure.canceled]' | sed 's/\[//' | sed 's/\]//')
      local direct0=$(echo "$json" | jq '[.connection[].departure.direction.name]' | sed 's/\[//' | sed 's/\]//')
      local arrival0=$(echo "$json" | jq '[.connection[].arrival.time]' | sed 's/\[//' | sed 's/\]//')
      break
   fi  
   cpt=$[$cpt+1]
done
#  echo "json = $json"
local connections="$(echo -e "${conn0}" | tr -d '[:space:]' | tr -d '[="=]')" 
local delays="$(echo -e "${delay0}" | tr -d '[:space:]' | tr -d '[="=]')"
local cancels="$(echo -e "${cancel0}" | tr -d '[:space:]' | tr -d '[="=]')"
local directs="$(echo -e "${direct0}" | tr -d '[:space:]' | tr -d '[="=]')"
local arrivals="$(echo -e "${arrival0}" | tr -d '[:space:]' | tr -d '[="=]')" 
# echo $connections
# echo $arrivals
IFS=',' read -a conn <<< $connections
IFS=',' read -a dela <<< $delays
IFS=',' read -a canc <<< $cancels
IFS=',' read -a dire <<< $directs
IFS=',' read -a arri <<< $arrivals
#echo ${#conn[@]}
local cpt=0
for  n in ${!conn[*]}
do
   local arrivaltime=`date --date="@${arri[$n]}" +%R` 
   echo `date --date="@${conn[$n]}" +%R`
   echo ". $jv_pg_sncb_direction ${dire[$n]}"
   if (( ${canc[$n]} == "0" )); then
      if (( ${dela[$n]} == "0" )); then
         echo ". $jv_pg_sncb_nodelay" 
      else
         echo ". $jv_pg_sncb_delay $((${dela[$n]}/60)) minutes" 
      fi 
      echo ". $jv_pg_sncb_arrival $arrivaltime "
   else   
      echo ". $jv_pg_sncb_warning . $jv_pg_sncb_deleted" 
   fi
   cpt=$[$cpt+1]
   if (( "$cpt" > "1" ))
   then
      break
   fi
   echo ". $jv_pg_sncb_then ."
done
}

