#/usr/bin/env bash
grep '^[0-9A-F]' /usr/share/unicode/emoji/emoji-test.txt | awk -F'#' '{gsub(/^[ \t]+/,"",$2); gsub(/ E[0-9]+\.[0-9]+/,"",$2); print $2}' | wmenu -l 10 -f "JetBrainsMono Nerd Font 16" -N "#0B042B" -M "6d6bff" -S "#AA7CFF" -n "#FFFFFF" -m "#FFFFFF" -s "#FFFFFF" -i -p "Emoji:" | awk '{printf "%s",$1}' | wl-copy
