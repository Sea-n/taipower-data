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

	### Download data ###
	curl -s "$baseurl/genary.json" | jq . > "$dir/genary_$time.json"  # 各機組發電量
	curl -s "$baseurl/loadpara.json" | jq . > "$dir/loadpara_$time.json"  # 今日電力資訊
	curl -s "$baseurl/loadpara.txt" > "$dir/loadpara_$time.txt"  # 今日電力資訊

	curl -s "$baseurl/genloadareaperc.csv" >> "$dir/genloadareaperc_$date.csv"  # 今日發電曲線(區域別)

	curl -s "$baseurl/loadareas.csv" | awk -F, '$3' > "$dir/loadareas_$time.csv"  # 今日用電曲線(區域別)
	curl -s "$baseurl/loadfueltype.csv" | awk -F, '$3' > "$dir/loadfueltype_$time.csv"  # 今日用電曲線(能源別)

	### Remove redundant data ###
	if [[ -e "$dir/loadareas_$prev.csv" ]]; then
		if [[ -z "$(comm -23 "$dir/loadareas_$prev.csv" "$dir/loadareas_$time.csv")" ]]; then
			rm "$dir/loadareas_$prev.csv"
		fi
	fi
	if [[ -e "$dir/loadfueltype_$prev.csv" ]]; then
		if [[ -z "$(comm -23 "$dir/loadfueltype_$prev.csv" "$dir/loadfueltype_$time.csv")" ]]; then
			rm "$dir/loadfueltype_$prev.csv"
		fi
	fi

	### Archive data everyday ###
	if [[ "$(date +%H:%M)" = "23:55" ]]; then
		mv "$dir/loadareas_$time.csv" "$dir/loadareas_$date.csv"
		mv "$dir/loadfueltype_$time.csv" "$dir/loadfueltype_$date.csv"

		git add "$(date +%Y)/"
		git commit -m "update: $(date -Idate) data"
		git push
	fi
}

main "$@"
