# Localização e Função dos Arquivos de Configuração

Este documento descreve a finalidade de cada arquivo no seu setup do Hyprland e Waybar.

## 🛠️ Waybar (Barra de Status)
Local: `~/.config/waybar/`

*   **`config.jsonc`**: Arquivo principal de configuração. Define quais módulos aparecem (relógio, bateria, spotify, etc.) e sua ordem.
*   **`style.css`**: Folha de estilo (CSS). Controla as cores, fontes, bordas arredondadas (pílulas) e o espaçamento da barra.
*   **`spotify-art.sh`**: Script que baixa/extrai a capa do álbum atual do Spotify para exibir na barra.
*   **`spotify-info.sh`**: Script que fornece metadados do Spotify (Artista - Título).
*   **`audio-output.sh`** & **`audio-input.sh`**: Scripts customizados para exibir volumes e ícones de entrada/saída de áudio dinamicamente.

## 🚀 Hyprland & Launcher (Wofi)
Local: `~/.config/hypr/`

*   **`hyprland.conf`**: O "cérebro" do sistema. Define atalhos de teclado (binds), configurações de mouse/monitor, e quais apps iniciam com o PC.
*   **`wofi.css`**: Estilização do menu de aplicativos e histórico de clipboard. Controla o tamanho do campo de busca e cores do menu.
*   **`launcher.sh`**: Script que abre o menu Wofi com dimensões específicas.
*   **`clipboard-listener.sh`**: Script que roda em background monitorando tudo que você copia (Ctrl+C).
*   **`clipboard-history.sh`**: Script acionado por atalho que abre o histórico de cópias recentes no Wofi para colagem rápida.

---

## 📦 Dependências Necessárias

Para que tudo funcione corretamente (scripts, ícones e barra), você precisa ter estes pacotes instalados:

### 核心 (Core)
*   **`hyprland`**: Window manager principal.
*   **`waybar`**: Barra de status.
*   **`wofi`**: Menu de apps e lançador.
*   **`hyprpaper`**: Gerenciador de papel de parede.
*   **`kitty`**: Terminal padrão usado em atalhos.

### 🔊 Áudio e Mídia
*   **`playerctl`**: Controle de música (Spotify/Cava).
*   **`cava`**: Visualizador de áudio na barra.
*   **`pulseaudio`** ou **`pipewire-pulse`**: Para o comando `pactl` usado nos scripts de volume.
*   **`pavucontrol`**: Interface gráfica de controle de volume.

### 📋 Utilitários de Sistema
*   **`wl-clipboard`**: Necessário para copiar/colar via terminal e scripts.
*   **`cliphist`** (opcional/alternativo): Usado em setups de histórico de clipboard.
*   **`libnotify`**: Para as notificações (`notify-send`) dos scripts.
*   **`network-manager-applet`**: Ícone de Wi-Fi (`nm-applet`).
*   **`grim`** & **`slurp`**: Capturas de tela (Print Screen).
*   **`curl`**: Necessário para baixar as capas do Spotify.

### 🎨 Visual (Fontes e Ícones)
*   **`ttf-jetbrains-mono-nerd`**: Fonte principal com ícones.
*   **`ttf-font-awesome`**: Ícones adicionais usados no CSS.

---

## 📥 Comandos de Instalação

### Arch Linux (Recomendado)
```bash
# Instalar pacotes principais
sudo pacman -S hyprland waybar wofi hyprpaper kitty playerctl cava pavucontrol wl-clipboard libnotify network-manager-applet grim slurp curl

# Instalar fontes e ícones (via AUR/Yay)
yay -S ttf-jetbrains-mono-nerd ttf-font-awesome
```

### Debian / Ubuntu / Mint
*Nota: Versões muito antigas podem não ter o Hyprland nos repositórios oficiais.*
```bash
sudo apt update
sudo apt install waybar wofi kitty playerctl cava pavucontrol wl-clipboard libnotify-bin network-manager-gnome grim slurp curl fonts-font-awesome
```
*(As fontes JetBrains Mono Nerd e o Hyprland no Debian/Ubuntu geralmente requerem instalação manual ou via PPA/Script de terceiros).*

---
*Gerado automaticamente pelo Gemini CLI em 29/05/2026.*
