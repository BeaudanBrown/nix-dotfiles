#!/usr/bin/env bash
# Create today's date folder
date_folder="$HOME/.local/share/gpt/$(date +%Y-%m-%d)"
mkdir -p "$date_folder"

# For each .aichat file in ~/.local/share/gpt/
for ai_file in "$HOME/.local/share/gpt/"*.aichat; do
	name=$(basename "$ai_file")
	dest="$date_folder/$name"
	if [ ! -f "$dest" ]; then
		cp "$ai_file" "$dest"
		chmod 755 "$dest"
	fi
done

# Change to the date directory
cd "$date_folder" || exit

# Open default chat with vim
nvim \
	-c "autocmd BufLeave <buffer> silent! write" \
	-c 'normal G' \
	-c 'normal o' \
	-c 'startinsert!' -O default.aichat
