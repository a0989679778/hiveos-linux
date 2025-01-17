#!/usr/bin/env bash


stats_raw=`curl --connect-timeout 2 --max-time ${API_TIMEOUT} --silent --noproxy '*' http://127.0.0.1:${MINER_API_PORT}/summary`
if [[ $? -ne 0 || -z $stats_raw ]]; then
	echo -e "${YELLOW}Failed to read $miner from localhost:${MINER_API_PORT}${NOCOLOR}"
else
	
	local temp=$(jq '.temp' <<< $gpu_stats)
	local fan=$(jq '.fan' <<< $gpu_stats)
	[[ $cpu_indexes_array != '[]' ]] && #remove Internal Gpus
		temp=$(jq -c "del(.$cpu_indexes_array)" <<< $temp) &&
		fan=$(jq -c "del(.$cpu_indexes_array)" <<< $fan)
	local ver=`echo $stats_raw | jq -c -r ".Software" | sed 's/lolMiner //'`
	local bus_numbers=$(echo $stats_raw | jq -r ".GPUs[].PCIE_Address" | cut -f 1 -d ':' | jq -sc .)
	local algo=""
	case "$(echo $stats_raw | jq -r '.Mining.Coin')" in
		BEAM)
			algo="equihash 150/5/3"
			;;
		BEAM-I)
			algo="equihash 150/5"
			;;
		BEAM-II)
			algo="equihash 150/5/3"
			;;
		BEAM-III)
			algo="beamhashv3"
			;;
		EXCC)
			algo="equihash 144/5"
			;;
		MWC-C29|GRIN-C29M)
			algo="cuckoo"
			;;
		MWC-C31)
			algo="cuckootoo31"
			;;
		GRIN-C32)
			algo="cuckootoo32"
			;;
		ZEL)
			algo="equihash 125/4"
			;;
		*)
			algo=$(echo $stats_raw | jq -r '.Mining.Algorithm')
			[[ $algo == "BeamHash III" ]]   && algo="beamhashv3"
			[[ $algo == "Cuckoo 29" ]]      && algo="cuckoo cycle"
			[[ $algo == "Cuckaroo 29-40" ]] && algo="cuckaroo29b"
			[[ $algo == "Cuckaroo 29-48" ]] && algo="cuckaroo29i"
			[[ $algo == "Cuckaroo 29-32" ]] && algo="cuckaroo29s"
			;;
	esac
	local Rejected=`echo $stats_raw | jq -c -r ".Session.Submitted - .Session.Accepted"`
	local ver=`echo $stats_raw | jq -c -r ".Software" | awk '{ print $2 }'`
	
	if [[ "$ver" > "1.09" && "$algo" == "Ethash" || "$algo" == "Etchash" ]]; then
		units="mhs"
		khs=`echo $stats_raw | jq -r '.Session.Performance_Summary' | awk '{ print $1*1000 }'`
	else
		khs=`echo $stats_raw | jq -r '.Session.Performance_Summary' | awk '{ print $1/1000 }'`
		units="hs"
	fi
	algo=`echo "$algo" | awk '{print tolower($0)}'`
	[[ $Rejected -lt 0 ]] && Rejected=0
	stats=$(jq 	--argjson temp "$temp" \
			--argjson fan "$fan" \
			--arg ver "$ver" \
			--argjson bus_numbers "$bus_numbers" \
			--arg algo "$algo" \
			--arg rej "$Rejected" \
			--arg units "$units" \
			--arg inv_all "$(echo $stats_raw | jq '[.GPUs[].Session_HWErr] | add')" \
			--arg inv_gpu "$(echo $stats_raw | jq '.GPUs[].Session_HWErr' | jq -cs '.' | sed  's/,/;/g' | tr -d [ | tr -d ])" \
			'{hs: [.GPUs[].Performance], hs_units: $units, $temp, $fan, uptime: .Session.Uptime, ar: [ .Session.Accepted, $rej, $inv_all, $inv_gpu ], $bus_numbers, algo: $algo, ver: $ver}' <<< "$stats_raw")
fi

[[ -z $khs ]] && khs=0
[[ -z $stats ]] && stats="null"
