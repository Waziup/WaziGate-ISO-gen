#!/usr/bin/env bash

# This script reconnects to known wifis after the WaziGate lost connection to them 

declare -i MINIMUM_SIGNAL_STRENGTH=20
ACCESS_POINT_SET_BY_USER=/etc/do_not_reconnect_wifi
ACTIVE_WIFI=$(nmcli c show --active | grep WAZIGATE-AP | awk '{print $1}')


# Skip when the access point was set by user
if [[ ${ACTIVE_WIFI} == 'WAZIGATE-AP' ]] && [[ -f "$ACCESS_POINT_SET_BY_USER" ]]; then
    echo "Access point was set by user: $ACCESS_POINT_SET_BY_USER file exists."
# Check whether we have to delete do_not_reconnect file 
elif [[ ${ACTIVE_WIFI} != 'WAZIGATE-AP' ]] && [[ -f "$ACCESS_POINT_SET_BY_USER" ]]; then
    echo "Gateway is not in access point mode. Delete file: $ACCESS_POINT_SET_BY_USER."
    rm -f "${ACCESS_POINT_SET_BY_USER}" 2> /dev/null
# Check whether non user set access point was activated (wifi connection lost)
elif [[ ${ACTIVE_WIFI} == 'WAZIGATE-AP' ]]; then
    echo "The Gateway is in access point mode, connection was lost."

    # Trigger rescan of available access points in 
    nmcli device wifi rescan
    iw dev wlan0 scan ap-force >/dev/null 2>&1

    declare -a IFS=$'' known_wifis=($(cat /etc/NetworkManager/system-connections/*.nmconnection | grep -w id | sed 's/.*=//'))

    for output in ${known_wifis[@]}
    do
        # Skip WAZIGATE-AP connect
        if [ ${output} != WAZIGATE-AP ]; then
            #echo "Found other known WIFI in NetworkManager: ${output}"
            declare -i current_signal_strength=($(nmcli -t -f SSID,SIGNAL dev wifi list | grep "${output}" | cut -d ":" -f2- | head -n 1))

            # Wifi access point have to be in range: lower border: MINIMUM_SIGNAL_STRENGTH
            if [[ current_signal_strength -ge MINIMUM_SIGNAL_STRENGTH ]]; then
                echo "Found known network with SSID: ${output} which has a signal strength of: ${current_signal_strength}."

                if [ -z ${best_wifi_in_range+x} ]; then 
                    echo "Access point in range was found."
                    best_wifi_in_range="$output:$current_signal_strength"
                else 
                    #echo "compare : old: $(echo $best_wifi_in_range | cut -d ":" -f2-) new: $current_signal_strength"
                    if [[ current_signal_strength -ge $(echo $best_wifi_in_range | cut -d ":" -f2-) ]]; then
                        echo "Found another Access point with better signal."
                        best_wifi_in_range="$output:$current_signal_strength"
                    fi
                fi
            fi
        fi
    done

    # no known wifi in range with good signal
    if [ -z ${best_wifi_in_range} ]; then
        echo "No known wifi in range, stay in access point mode for now. Access point had not been set by user."
    # connect to best wifi in range
    else
        echo "SSID with best signal: $best_wifi_in_range."
        nmcli dev wifi connect $(echo $best_wifi_in_range | cut -d ":" -f1)
        unset output
    fi

else
    echo "Gateway is still connected to access point."
fi