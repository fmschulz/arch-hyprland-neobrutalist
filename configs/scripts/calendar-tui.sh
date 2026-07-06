#!/usr/bin/env bash
set -euo pipefail

month="$(date +%m)"
year="$(date +%Y)"
view="${1:-month}"

shift_month() {
	local offset="$1"
	local next
	next="$(date -d "${year}-${month}-01 ${offset} month" +%Y-%m)"
	year="${next%-*}"
	month="${next#*-}"
}

draw() {
	clear
	printf 'Calendar\n'
	printf '========\n\n'

	if [[ "${view}" == "--year" || "${view}" == "year" ]]; then
		printf '%s\n\n' "${year}"
		cal -m -w -y "${year}"
	else
		printf '%s\n\n' "$(date -d "${year}-${month}-01" '+%B %Y')"
		cal -m -w "$((10#${month}))" "${year}"
	fi

	printf '\n'
	printf 'Left/Right or p/n: previous/next month\n'
	printf 'Up/Down or P/N: previous/next year\n'
	printf 'y: year view   m: month view   t: today   q/Esc: close\n'
}

while true; do
	draw
	IFS= read -rsn1 key || exit 0

	if [[ "${key}" == $'\e' ]]; then
		IFS= read -rsn2 -t 0.05 rest || rest=""
		case "${rest}" in
			"[D") shift_month -1 ;;
			"[C") shift_month 1 ;;
			"[A") year=$((year - 1)) ;;
			"[B") year=$((year + 1)) ;;
			*) exit 0 ;;
		esac
		continue
	fi

	case "${key}" in
		p) shift_month -1 ;;
		n) shift_month 1 ;;
		P) year=$((year - 1)) ;;
		N) year=$((year + 1)) ;;
		y) view="year" ;;
		m) view="month" ;;
		t)
			month="$(date +%m)"
			year="$(date +%Y)"
			view="month"
			;;
		q) exit 0 ;;
	esac
done
