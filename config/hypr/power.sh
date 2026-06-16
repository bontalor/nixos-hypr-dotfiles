#!/usr/bin/env bash
choice=$(printf "logout\nsuspend\nlock\nreboot\npower off" | wmenu -l 10 -f "JetBrainsMono Nerd Font 16" -N "#0B042B" -M "6d6bff" -S "#AA7CFF" -n "#FFFFFF" -m "#FFFFFF" -s "#FFFFFF" -p "Power:")
case "$choice" in
    logout)
        loginctl kill-session "$XDG_SESSION_ID"
        ;;
    suspend)
        systemctl suspend
        ;;
    lock)
	loginctl lock-session
	;;
    reboot)
        systemctl reboot
        ;;
    "power off")
        systemctl poweroff
        ;;
esac
