#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
source_app="${project_dir}/dist/iyh.app"
destination_app="/Applications/iyh.app"
legacy_app="/Applications/[eq.app"

"${script_dir}/build.sh"

if [[ -e "${destination_app}" ]]; then
    backup_app="/Applications/iyh.backup.$(date +%Y%m%d-%H%M%S).app"
    mv "${destination_app}" "${backup_app}"
    print "Previous version moved to ${backup_app}"
fi

if [[ -e "${legacy_app}" ]]; then
    legacy_backup_app="/Applications/[eq.backup.$(date +%Y%m%d-%H%M%S).app"
    mv "${legacy_app}" "${legacy_backup_app}"
    print "Previous [eq version moved to ${legacy_backup_app}"
fi

ditto "${source_app}" "${destination_app}"
open "${destination_app}"
print "Installed and launched ${destination_app}"
