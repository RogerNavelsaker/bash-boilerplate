#!/usr/bin/env bash

# Bash Boilerplate Builder (build.sh)
#
# Generates a standalone.sh by combining core.sh & main.sh.

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly core_file="${script_dir}/core.sh"
readonly main_file="${script_dir}/main.sh"
readonly output_file="${script_dir}/standalone.sh"

if [[ ! -f "$core_file" ]] || [[ ! -f "$main_file" ]]; then
    echo "Error: core.sh and main.sh must exist in ${script_dir}" >&2
    exit 1
fi

echo "Building standalone script..."

# 1. Prepare core content (strip header)
tmp_core=$(mktemp)
sed -n '/# BOILERPLATE_CORE_START/,$p' "$core_file" | sed '1d' > "$tmp_core"

# 2. Prepare main (strip local sourcing)
tmp_main_content=$(mktemp)
sed '/# BOILERPLATE_MAIN_START/,/fi/d' "$main_file" > "$tmp_main_content"

# 3. Inject core content into the main content
tmp_standalone=$(mktemp)
# Keep first 8 lines (shebang and headers)
head -n 8 "$tmp_main_content" > "$tmp_standalone"
# Inject core functions
cat "$tmp_core" >> "$tmp_standalone"
# Append rest of main.sh
sed '1,8d' "$tmp_main_content" >> "$tmp_standalone"

# 4. Clean up and finalize
mv "$tmp_standalone" "$output_file"
chmod +x "$output_file"
rm "$tmp_core" "$tmp_main_content"

echo "Done! Standalone script generated at ${output_file}"
