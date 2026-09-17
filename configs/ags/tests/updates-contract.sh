#!/usr/bin/env bash

set -euo pipefail

config_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
update_script="${config_root}/scripts/updates-waybar.sh"
app="${config_root}/ags/app.tsx"
fixture_dir=$(mktemp -d)
trap 'rm -rf "${fixture_dir}"' EXIT

for command in bash awk jq; do
	ln -s "$(command -v "${command}")" "${fixture_dir}/${command}"
done

run_case() {
	PATH="${fixture_dir}" "${update_script}"
}

assert_json() {
	local output=$1
	local expression=$2
	local message=$3
	jq -e "${expression}" <<<"${output}" >/dev/null || {
		printf 'updates-contract: FAIL: %s\n' "${message}" >&2
		exit 1
	}
}

printf '%s\n' '#!/usr/bin/env bash' "printf 'linux 1 -> 2\\nmesa 1 -> 2\\n'" >"${fixture_dir}/checkupdates"
chmod +x "${fixture_dir}/checkupdates"
pending=$(run_case)
assert_json "${pending}" '.class == "pending" and .text == "󰏗 2"' "pending updates were not counted"

printf '%s\n' '#!/usr/bin/env bash' 'exit 2' >"${fixture_dir}/checkupdates"
chmod +x "${fixture_dir}/checkupdates"
none=$(run_case)
assert_json "${none}" '.class == "none" and .text == "" and .tooltip == "System up to date"' "exit 2 was not treated as no updates"

printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"${fixture_dir}/checkupdates"
chmod +x "${fixture_dir}/checkupdates"
failed=$(run_case)
assert_json "${failed}" '.class == "error" and (.text | length > 0) and .tooltip != "System up to date"' "checker failure was hidden"

rm "${fixture_dir}/checkupdates"
missing=$(run_case)
assert_json "${missing}" '.class == "error" and (.text | length > 0) and .tooltip != "System up to date"' "missing checker was reported as up to date"

[[ $(grep -c 'sudo pacman -Syu' "${app}") -eq 1 ]] || {
	printf 'updates-contract: FAIL: installer command must appear exactly once\n' >&2
	exit 1
}
grep -Fq 'onClicked={() => void installUpdates()}' "${app}" || {
	printf 'updates-contract: FAIL: installer command is not confined to the update click handler\n' >&2
	exit 1
}
grep -Fq 'await refreshUpdates()' "${app}" || {
	printf 'updates-contract: FAIL: update status is not refreshed after the installer exits\n' >&2
	exit 1
}
if grep -Fq 'pkill -RTMIN+9 waybar' "${app}"; then
	printf 'updates-contract: FAIL: AGS still signals the retired Waybar process\n' >&2
	exit 1
fi

printf 'updates-contract: PASS\n'
