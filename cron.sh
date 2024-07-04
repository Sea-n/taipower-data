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

	### Download data ###
	curl -s "$baseurl/genary.json" | jq . > "genary_$time.json"  # 各機組發電量
	curl -s "$baseurl/loadpara.json" | jq . > "loadpara_$time.json"  # 今日電力資訊
	curl -s "$baseurl/loadpara.txt" | tr -d '\r' > "loadpara_$time.txt"  # 今日電力資訊

	curl -s "$baseurl/genloadareaperc.csv" | tr -d '\r' >> "genloadareaperc_$date.csv"  # 今日發電曲線 (區域別)

	curl -s "$baseurl/loadareas.csv" | awk -F, '$3' | tr -d '\r' > "loadareas_$time.csv"  # 今日用電曲線 (區域別)
	curl -s "$baseurl/loadfueltype.csv" | awk -F, '$3' | tr -d '\r' > "loadfueltype_$time.csv"  # 今日用電曲線 (能源別)

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
