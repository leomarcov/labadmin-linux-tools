#!/bin/bash


# MAIN CONFIG  
log_file="/var/log/quota_labadmin"		            # File where save events
log_email="logs.carlos3@gmail.com"		            # Email for log messages
cache_file="/var/cache/labadmin/labdmin_quota"      # Cache file for save last warning state
max_time_left=24									# Default time left in hours for bad_user can free space	



#=== FUNCTION ==================================================================
#        NAME: check_parameters
# DESCRIPTION: check parameters
#===============================================================================
function check_parameters() {
	# CHECK ROOT
	if [ "$(id -u)" -ne 0 ]; then
		echo "Must be run as root"
		exit 1
	fi
	# CHECK PARAMETERS
	if [ "$#" -lt 2 ] || [ "$1" -ne "$1" ]&>/dev/null || [ "$2" -ne "$2" ]&>/dev/null; then 
		echo "Usage: $(basename $0) min_size_root min_size_home"
		exit 1
	fi	
}



#=== FUNCTION ==================================================================
#        NAME: KtoG
# DESCRIPTION: convert $1 KB in x.xGB and echo in STDOUT
# PARAMETERS:
#	[$1]: number of KB
#===============================================================================
function KtoG() {
	local k="$1"
	local n1="$((k/(1024*1024)))"
	local n2="$((k%(1024*1024)*10/(1024*1024)))"
	local n="$n1"
	[ "$n2" -ne 0 ] && n="${n}.$n2"
	echo "$n"
}





#=== FUNCTION ==================================================================
#        NAME: alert_event
# DESCRIPTION: show user message for alert 24 hours left to delete files
#              and log the event in file and email
#===============================================================================
function alert_event() {
	# GET SIZE VALUES
	du_home="$(cd "$mount_point"; du -sh * | sort -hr | grep -v "lost+found")"		# du /homme in GB
	du_user="$(du -h -d 2 "${mount_point}/${bad_user[0]}" | head -n -1 | sort -hr | egrep '^[0-9,.]+G[[:blank:]]')"		# main user folders size
	del_candidate="$(echo "$du_user" | grep "/.*/.*/.*/.*" | head -1)"
	home_total_size="$(df ${mount_point} | tail -1 | awk '{print $2}')"
	home_free_size="$(df ${mount_point} | tail -1 | awk '{print $4}')"
	others_size="$((${home_total_size}-${home_free_size}-${bad_user[1]}-${next_user[1]}))"


	# LOG EVENT (FILE AND MAIL)
	echo -e "[$(date "+%F_%T")][QUOTA-HOME]  ${bad_user[0]}:${bad_user[1]}\t${next_user[0]}:${next_user[1]}" >> "$log_file"
	echo -e "### DATE ##############################
Date: $(date "+%Y/%m/%d")
Time: $(date "+%H:%M")

### USER ##############################
User: ${bad_user}
Left time: ${time_left} hours
Alert count: ${alert_count}

### FILE SYSTEMS ##############################
$(df -h)

### $mount_point ##############################
${du_home}

### ${mount_point}/${bad_user[0]} ##############################
${du_user}
" | mail -s "【labadmin】【$(hostname)】【QUOTA-HOME】" -a "From: $(hostname) <$(hostname)@carlos3.com>" "$log_email"


	# SHOW MESSAGE
	bar_size=80
	msg='
                                                                 
   ███╗   ██╗ ██████╗  ██████╗  ██████╗  ██████╗ ██╗██╗██╗
   ████╗  ██║██╔═══██╗██╔═══██╗██╔═══██╗██╔═══██╗██║██║██║
   ██╔██╗ ██║██║   ██║██║   ██║██║   ██║██║   ██║██║██║██║
   ██║╚██╗██║██║   ██║██║   ██║██║   ██║██║   ██║╚═╝╚═╝╚═╝
   ██║ ╚████║╚██████╔╝╚██████╔╝╚██████╔╝╚██████╔╝██╗██╗██╗
   ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝  ╚═════╝  ╚═════╝ ╚═╝╚═╝╚═╝

   EL ESPACIO LIBRE EN '${mount_point}' ES MENOR A '${min_size}'GB
   ESTO PUEDE SER PROBLEMÁTICO

   PARECE SER QUE TÚ ERES EL PRINCIPAL RESPOSABLE DE ESTO:
'$(

echo -en "   \e[91m$(seq -s "█" 0 $((bar_size*bad_user[1]/home_total_size)) | tr -d "[0-9]")"
echo -en "\e[94m$(seq -s "█" 0 $((bar_size*next_user[1]/home_total_size)) | tr -d "[0-9]")"
echo -en "\e[97m$(seq -s "█" 1 $((bar_size*others_size/home_total_size)) | tr -d "[0-9]")"
echo -e "\e[0m$(seq -s "▒" 0 $((bar_size*home_free_size/home_total_size)) | tr -d "[0-9]")\e[0m ($(KtoG $home_total_size)GB)"

echo -e "     \e[1m\e[31m${bad_user[0]} ($(KtoG ${bad_user[1]})GB)   \e[34m${next_user[0]} ($(KtoG ${next_user[1]})GB)   \e[97motros ($(KtoG $others_size)GB)   \e[90mlibre ($(KtoG $home_free_size)GB)\e[0m"
)'


   * TIENES UN MARGEN DE \e[41m\e[1m'${time_left}' HORAS\e[0m PARA ELIMINAR DATOS Y DEJAR \e[1m\e[41m'${mount_point}'\e[0m CON AL MENOS \e[1m\e[41m'${min_size}'GB\e[0m
   * SI NO REDUCES EL ESPACIO SE ELIMINARÁN AUTOMÁTICAMENTE TUS DATOS
   * EL CANDIDATO PARA LA AUTOELIMINACIÓN ES: \e[1m\e[41m'"$(echo "${del_candidate}"|cut -f 2) ($(echo "${del_candidate}"|cut -f 1))"'\e[0m


Presiona ENTER para mostrar tu espacio ocupado...'

	# Open user window
	su -l "${logged_user[0]}" -c "DISPLAY=${logged_user[1]} xhost +" >/dev/null
	su -l "${logged_user[0]}" -c "DISPLAY=${logged_user[1]} terminator -f -b -x bash -c \"echo -e '$msg'; read; echo -e '$du_user'| egrep --color '[0-9,.]+G|[0-9]{3}M'; read\"" 2>/dev/null
}



function ultimatum_event() {
	# GET SIZE VALUES
	du_home="$(cd "$mount_point"; du -sh * | sort -hr | grep -v "lost+found")"		# du /homme in GB

	# LOG EVENT (FILE AND MAIL)
	echo -e "[$(date "+%F_%T")][QUOTA-ULTIMATUM]  ${bad_user[0]}:${bad_user[1]}\t${next_user[0]}:${next_user[1]}" >> "$log_file"
	echo -e "### DATE ##############################
Date: $(date "+%Y/%m/%d")
Time: $(date "+%H:%M")

### USER ##############################
User: ${cached_bad_user}
Left time: ${time_left} hours
Alert count: ${alert_count}

### FILE SYSTEMS ##############################
$(df -h)

### $mount_point ##############################
${du_home}

" | mail -s "[labadmin] [$(hostname)] [QUOTA-ULTIMATUM]" -a "From: $(hostname) <$(hostname)@carlos3.com>" "$log_email"

	msg='

   \e[90m##########################################################################################################
   \e[90m#\e[1m\e[95m         _____ ____                                                                                     \e[0m\e[90m#
   \e[90m#\e[1m\e[95m        \`----,\    )                                                                                    \e[0m\e[90m#
   \e[90m#\e[1m\e[95m         \`--==\\  /             \e[0mEL TIEMPO DE GRACIA PARA ELIMINAR TUS DATOS HA EXPIRADO                  \e[0m\e[90m#
   \e[90m#\e[1m\e[95m          \`--==\\/              \e[0mEL ADMINISTRADOR BORRARÁ TUS DATOS EN BREVE                              \e[0m\e[90m#
   \e[90m#\e[1m\e[35m        .-~~~~-.Y|\\_           \e[0m(LE ENCANTA BORRAR MÁQUINAS VIRTULES WINDOWS)                            \e[0m\e[90m#
   \e[90m#\e[1m\e[95m     @_/        /  \e[0m66\e[1m\e[35m\_                                                                                 \e[0m\e[90m#
   \e[90m#\e[1m\e[95m       |    \   \   _(\")       \e[0mPUEDE QUE TODAVÍA ESTÉS A TIEMPO DE GUARDARLOS TÚ MISMO                  \e[0m\e[90m# 
   \e[90m#\e[1m\e[95m        \   /-| ||'\''--'\''           \e[0mO PUEDE QUE NO... Y SE PIERDAN ENTRE BITS Y BITS EN EL CYBERESPACIO...   \e[0m\e[90m# 
   \e[90m#\e[1m\e[95m         \_\  \_\\                                                                                       \e[0m\e[90m#
   \e[90m#                                                                                                        \e[0m\e[90m#
   \e[90m##########################################################################################################
'

	# Open user window
	su -l "${logged_user[0]}" -c "DISPLAY=${logged_user[1]} xhost +" >/dev/null
 	su -l "${logged_user[0]}" -c "DISPLAY=${logged_user[1]} terminator -f -b -x bash -c \"echo -e '$msg'; read;\"" 2>/dev/null
}




### CHECK PARAMETERS
check_parameters $@


##################################################
### CHECK ROOT PARTITION
##################################################
min_size="$1"							
mount_point="/"							
left_size="$(df "${mount_point}" | tail -1 | awk '{print $4}')"		# Left size in KB

# If root partition space is less than $min_size email to admin (no show message)
if [ "$left_size" -lt $((${min_size}*1024*1024)) ]; then
	df -h | grep "/dev/sd" | mail -s "[labadmin] [$(hostname)] [QUOTA-ROOT]" -a "From: $(hostname) <$(hostname)@carlos3.com>" "$log_email"
fi



##################################################
### CHECK HOME PARTITION
##################################################
min_size="$2"
mount_point="/home"					

### GET CACHED DATA
current_time="$(date +%s)"
time_left="$max_time_left"
alert_count=1
if [ -r "$cache_file" ]; then
	cached_time="$(grep "cached_time=" "$cache_file" | cut -f2 -d=)"
	cached_bad_user="$(grep "cached_bad_user" "$cache_file" | cut -f2 -d=)"
	cached_alert_count="$(grep "cached_alert_count" "$cache_file" | cut -f2 -d=)"
	alert_count=$((cached_alert_count+1))
	time_left="$((max_time_left-(current_time-cached_time)/3600))"
fi


### CHECK IF LEFT SIZE IS ENOUGHT
left_size="$(df "${mount_point}" | tail -1 | awk '{print $4}')"		# Left size in KB
if [ "$left_size" -ge "$((${min_size}*1024*1024))"  ]; then
	if [ -f "$cache_file" ]; then
		# LOG RESTORED SPACE OK
		echo -e "[$(date "+%F_%T")][QUOTA-RESTORED] ${cached_bad_user}:${time_left}h" >> "$log_file"
		echo -e "### DATE ##############################
Date: $(date "+%Y/%m/%d")
Time: $(date "+%H:%M")

### USER ##############################
User: ${cached_bad_user}
Left time: ${time_left} hours
Alert count: ${cached_alert_count}

### FILE SYSTEMS ##############################
$(df -h)" | mail -s "[labadmin] [$(hostname)] [QUOTA-RESTORED]" -a "From: $(hostname) <$(hostname)@carlos3.com>" "$log_email"
		
		# Remove cache file
		rm "$cache_file"
	fi
	exit 0
fi


### GET SIZE VALUES
du_home="$(cd "$mount_point"; du -s * | sort -h | grep -v "lost+found")"		# du in KB
bad_user[0]="$(echo "$du_home" | tail -1 | cut -f 2)"							# username
bad_user[1]="$(echo "$du_home" | tail -1 | cut -f 1)"							# size in KB
next_user[0]="$(echo "$du_home" | tail -2 | head -1 | cut -f 2)"				# username
next_user[1]="$(echo "$du_home" | tail -2 | head -1 | cut -f 1)"				# size in KB
[ "$next_user" = "$bad_user" ] && next_user=("" 0)


### CHECK LOGGED USER
logged_user=($(w -oshu | grep "[[:blank:]]:[0-9][[:blank:]]" | grep -o "^[a-z][-a-zA-Z0-9]\+\|[[:blank:]]:[0-9][[:blank:]]" | sed -z 's/\n[[:blank:]]:/ :/g' | sort -u))	# logged_user[0]=username  logged_user[1]=:0
[ "${bad_user[0]}" != "$logged_user" ] && exit 0							


### CREATE CACHE FILE
if [ ! "$cached_time" ] || [ "${bad_user[0]}" != "$cached_bad_user" ]; then
	[ ! -d "$(dirname "$cache_file")" ] && mkdir "$(dirname "$cache_file")"
	echo "# QUOTA LABADMIN CACHE
cached_time=${current_time}
cached_bad_user=${bad_user[0]}
cached_alert_count=1
" > "$cache_file"
	time_left="$max_time_left"
	alert_count=1
### INC ALERT COUNT IN CACHE FILE
elif [ "$cached_time" ]; then
	sed -i "s/cached_alert_count=[0-9]\+/cached_alert_count=${alert_count}/g" "$cache_file"
fi


### NO TIME LEFT ALERT ULTIMATUM
if [ "$time_left" -lt 0 ]; then
	ultimatum_event
### TIME LEFT ALERT 24HOURS
else
	alert_event
fi



