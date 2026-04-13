#!/usr/bin/env bash

# Bash Boilerplate Builder (build.sh)
#
# Generates a standalone template.sh by combining source.sh & script.sh.

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly source_file="${script_dir}/source.sh"
readonly script_file="${script_dir}/script.sh"
readonly output_file="${script_dir}/template.sh"

if [[ ! -f "${source_file}" ]] || [[ ! -f "${script_file}" ]]; then
    echo "Error: source.sh and script.sh must exist in ${script_dir}" >&2
    exit 1
fi

echo "Building standalone template.sh..."

# 1. Prepare source content (skip shebang and header)
tmp_source=$(mktemp)
sed '1,6d' "${source_file}" > "$tmp_source"

# 2. Prepare script by removing the local sourcing logic block
tmp_script=$(mktemp)
sed '/readonly __script_dir/,/fi/d' "${script_file}" > "$tmp_script"

# 3. Inject source content into the script content
tmp_template=$(mktemp)
# Keep first 8 lines of script.sh (shebang and headers)
head -n 8 "$tmp_script" > "$tmp_template"
# Inject the core functions
cat "$tmp_source" >> "$tmp_template"
# Append the rest of script.sh
sed '1,8d' "$tmp_script" >> "$tmp_template"

# 4. Clean up and finalize
mv "$tmp_template" "${output_file}"
chmod +x "${output_file}"
rm "$tmp_source" "$tmp_script"

echo "Done! Standalone script generated at ${output_file}"
