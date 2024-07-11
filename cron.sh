#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")" || exit 1

main() {
	baseurl='https://www.taipower.com.tw/d006/loadGraph/loadGraph/data'
	time="$(date -Iminutes | head -c15 | tr T _)0"  # e.g. 2024-07-03T12:40
	prev="$(date -Iminutes -v-10M | head -c15 | tr T _)0"  # e.g. 2024-07-03T12:30
	date="${time:0:10}"  # e.g. 2024-07-03
	dir="${time:0:4}/$date"  # e.g. 2024/2024-07-03

	mkdir -p "$dir/"
	cd "$dir/" || exit 1

	### Add header for 00:00 ###
	if [[ ! -e "loadpara_$date.tsv" ]]; then  # 今日電力資訊
		echo -e "time\treal_cap\tload\tutil_rate\tfore_cap\tfore_peak\tfore_resv\tfore_rate\tfore_indi\tfore_hour\tyday_cap\tyday_peak\tyday_resv\tyday_rate\tyday_indi\treal_peak" > "loadpara_$date.tsv"
	fi
	if [[ ! -e "genloadareaperc_$date.csv" ]]; then  # 今日發電曲線 (區域別)
		echo 'datetime,gen_north,load_north,gen_central,load_central,gen_south,load_south,gen_east,load_east' > "genloadareaperc_$date.csv"
	fi


	### Download data ###

	# 今日電力資訊
	curl -s "$baseurl/loadpara.json" | jq . > "loadpara_$time.json"
	curl -s "$baseurl/loadpara.txt" | tr -d '\r' > "loadpara_$time.txt"
	jq -r '.records | add | [.publish_time[-5:], .real_hr_maxi_sply_capacity, .curr_load, .curr_util_rate,
		.fore_maxi_sply_capacity, .fore_peak_dema_load, .fore_peak_resv_capacity,
		.fore_peak_resv_rate, .fore_peak_resv_indicator, .fore_peak_hour_range,
		.yday_maxi_sply_capacity, .yday_peak_dema_load, .yday_peak_resv_capacity,
		.yday_peak_resv_rate, .yday_peak_resv_indicator, .real_hr_peak_time] | @tsv' loadpara_$time.json >> loadpara_$date.tsv

	# 今日發電曲線 (區域別)
	curl -s "$baseurl/genloadareaperc.csv" | tr -d '\r' >> "genloadareaperc_$date.csv"
	curl -s "$baseurl/loadareas.csv" | awk -F, '$3' | tr -d '\r' > "loadareas_$time.csv"  # 今日用電曲線 (區域別)

	# 今日用電曲線 (能源別)
	curl -s "$baseurl/loadfueltype.csv" | awk -F, '$3' | tr -d '\r' > "loadfueltype_$time.csv"

	# 各機組發電量
	curl -s "$baseurl/genary.json" | jq . > "genary_$time.json"
	echo -e "能源別\t能源子類別\t機組名稱\t裝置容量\t淨發電量\t發電量比\t備註\t空欄位" > "genary_$time.tsv"
	jq -r '.aaData | map((.[0] |= gsub("<[^>]*>"; "")) | map(gsub("&amp;"; "&")))[] | @tsv' "genary_$time.json" >> "genary_$time.tsv"


	### Remove redundant data ###
	if [[ -e "loadareas_$prev.csv" ]]; then
		if [[ -z "$(comm -23 "loadareas_$prev.csv" "loadareas_$time.csv")" ]]; then
			rm "loadareas_$prev.csv"
		fi
	fi
	if [[ -e "loadfueltype_$prev.csv" ]]; then
		if [[ -z "$(comm -23 "loadfueltype_$prev.csv" "loadfueltype_$time.csv")" ]]; then
			rm "loadfueltype_$prev.csv"
		fi
	fi

	### Archive data everyday ###
	if [[ "${time:11}" = "23:50" ]]; then
		mv "loadareas_$time.csv" "loadareas_$date.csv"
		mv "loadfueltype_$time.csv" "loadfueltype_$date.csv"

		git add .
		git commit -m "update: $(date -Idate) data"
		git push
	fi
}

main "$@"
