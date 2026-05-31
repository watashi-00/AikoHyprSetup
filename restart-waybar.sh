#!/bin/bash

# Mata todas as instâncias do Waybar que estiverem rodando
killall waybar || true

# Aplica wallpaper (estático ou animado)
if [ -x ~/.config/waybar/wallpaper.sh ]; then
    ~/.config/waybar/wallpaper.sh apply
fi

# Aguarda um pequeno momento para garantir que os processos fecharam
sleep 0.5

# Inicia as três instâncias conforme sua configuração
waybar --config ~/.config/waybar/config.jsonc --style ~/.config/waybar/style.css &
waybar --config ~/.config/waybar/config-bottom.jsonc --style ~/.config/waybar/style.css &
waybar --config ~/.config/waybar/config-left.jsonc --style ~/.config/waybar/style.css &

echo "Waybars reiniciadas com sucesso!"
