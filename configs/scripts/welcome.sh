#!/bin/bash

[[ $- != *i* ]] && return

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

if command -v fastfetch >/dev/null 2>&1; then
  fastfetch --logo arch_small --structure Title:OS:Kernel:Uptime:Shell:WM:Terminal:CPU:Memory
  echo
fi

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}⌨${NC}  ${GREEN}Super+D${NC} launcher  ${GREEN}Super+Return${NC} terminal  ${GREEN}Super+Q${NC} close"
echo -e "${CYAN}📁${NC} ${GREEN}Super+E${NC} yazi      ${GREEN}Super+W${NC} wallpapers  ${GREEN}yy${NC} file manager"
echo -e "${CYAN}📻${NC} ${GREEN}Super+Shift+R${NC} radio ${GREEN}Super+A${NC} rename ws  ${GREEN}radio${NC} selector"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
