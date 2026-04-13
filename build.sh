#!/usr/bin/env bash

# Bash Boilerplate Builder (build.sh)
#
# Generates a standalone main.sh by injecting core.sh into template.sh.

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly core_file="${script_dir}/core.sh"
readonly template_file="${script_dir}/template.sh"
readonly output_file="${script_dir}/main.sh"

if [[ ! -f "${core_file}" ]] || [[ ! -f "${template_file}" ]]; then
    echo "Error: core.sh and template.sh must exist in ${script_dir}" >&2
    exit 1
fi

echo "Building standalone main.sh..."

# 1. Prepare core content (skip shebang and header)
tmp_core=$(mktemp)
sed '1,4d' "${core_file}" > "$tmp_core"

# 2. Prepare template by removing the local sourcing logic
# We want to remove the block between 'readonly __template_dir' and the corresponding 'fi'
tmp_template=$(mktemp)
# This sed command deletes the sourcing block specifically
sed '/readonly __template_dir/,/fi/d' "${template_file}" > "$tmp_template"

# 3. Inject core content into the template where the sourcing was
# We'll just put it at the top after the shebang/header
tmp_main=$(mktemp)
head -n 8 "$tmp_template" > "$tmp_main"
cat "$tmp_core" >> "$tmp_main"
sed '1,8d' "$tmp_template" >> "$tmp_main"

mv "$tmp_main" "${output_file}"
chmod +x "${output_file}"

rm "$tmp_core" "$tmp_template"

echo "Done! Standalone script generated at ${output_file}"
