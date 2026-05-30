# Localização e Função dos Arquivos de Configuração

Este documento descreve a finalidade de cada arquivo no seu setup do Hyprland e Waybar.

## 🛠️ Waybar (Barra de Status)
Local no Repo: `./` | Local no Sistema: `~/.config/waybar/`

*   **`config.jsonc`**: Arquivo principal (Top Bar). Define módulos como relógio, bateria e spotify.
*   **`config-bottom.jsonc`**: Configuração da barra inferior (estilo dock/pílula).
*   **`config-left.jsonc`**: Configuração para uma barra lateral esquerda (experimental).
*   **`config-screenshot.jsonc`**: Barra flutuante simplificada usada durante capturas de tela ou HUD.
*   **`style.css`**: CSS global para todas as barras. Controla cores, animações e o visual "pink anime".
*   **`restart-waybar.sh`**: Script para matar e reiniciar o Waybar aplicando as configurações.

### 🎵 Scripts de Mídia & Áudio
*   **`spotify-art.sh`**: Baixa e exibe a capa do álbum atual.
*   **`spotify-info.sh`**: Retorna "Artista - Título" para o módulo principal.
*   **`spotify-playstate.sh`**: Ícones dinâmicos de Play/Pause.
*   **`audio-output.sh`** & **`audio-input.sh`**: Exibição e controle de volume/mudo para fones e microfone.

## 🚀 Hyprland & Sistema
*   **`hypr-config/hyprland.conf`**: Backup da configuração principal do Hyprland (binds, regras de janela).
*   **`hyprland.conf.sample`**: Exemplo de configuração base.
*   **`minimize.sh`**: Script para gerenciar a "minimização" de janelas no Hyprland.
*   **`screenshot.sh`**: Atalho para tirar prints (tela cheia ou seleção) usando `grim` e `slurp`.

## 📂 Outros Apps (Backups)
*   **`mako-config/config`**: Configuração do Mako (notificações leves).
*   **`wofi-config/config`**: Configuração base do Wofi.
*   **`wofi-config/style.css`**: Estilização do menu Wofi. Deve ser arquivo real, não symlink para `~/.config`.
*   **`launcher.sh`**: Abre o Wofi como lançador de apps.
*   **`clipboard-history.sh`**: Abre o histórico de clipboard via Wofi (`cliphist`).
*   **`clipboard-listener.sh`**: Registra o clipboard no `cliphist` usando `wl-paste --watch`.

## 🔧 Manutenção
*   **`install.sh`**: Instalador universal. Detecta gerenciador de pacotes, instala dependências possíveis, copia payloads e cria backups.
*   **`update-backups.sh`**: Script para sincronizar os arquivos do sistema (`~/.config/...`) para este repositório.
*   **`files_location.md`**: Este guia de referência.
*   **`observations.md`**: Notas sobre bugs corrigidos e melhorias pendentes.

---

## 📦 Dependências Necessárias

### 核心 (Core)
*   **`hyprland`**, **`waybar`**, **`wofi`**, **`mako`**, **`hyprpaper`**, **`kitty`**, **`jq`**.

### 🔊 Áudio e Mídia
*   **`playerctl`**, **`cava`**, **`pipewire`**, **`pipewire-pulse`**/**`pipewire-pulseaudio`**, **`wireplumber`**, **`pavucontrol`**.
*   Os scripts de volume usam `pactl`; os binds do Hyprland usam `wpctl`.

### 📋 Utilitários de Sistema
*   **`wl-clipboard`**, **`cliphist`**, **`libnotify`/`libnotify-bin`**, **`network-manager-applet`/`network-manager-gnome`**, **`grim`**, **`slurp`**, **`curl`**, **`hyprpicker`**, **`swappy`**, **`xdg-utils`**, **`bluez`**.
*   `hyprpicker`, `swappy`, `bluetoothctl`, `pavucontrol`, `cava` e `nm-applet` são opcionais no sentido de que o desktop sobe sem eles, mas módulos/atalhos específicos perdem função.

### 🎨 Visual (Fontes e Ícones)
*   **JetBrains Mono Nerd Font** e **Font Awesome**.
*   O nome do pacote muda por distro: `ttf-jetbrains-mono-nerd`, `fonts-jetbrains-mono`, `jetbrains-mono-fonts`, `ttf-jetbrains-mono`; `ttf-font-awesome`, `fonts-font-awesome`, `fontawesome-fonts`, `font-awesome`.

---

## 📥 Instalador Universal

Rode a partir da raiz deste pacote:

```bash
./install.sh
```

Opções úteis:

```bash
./install.sh --dry-run      # simula cópias/instalação
./install.sh --no-packages  # só instala os arquivos de config
./install.sh --no-hypr      # não substitui ~/.config/hypr/hyprland.conf
```

O instalador:

*   Detecta `pacman`, `apt-get`, `dnf`, `zypper` ou `apk`.
*   Instala pacote por pacote e continua se algum nome não existir naquela versão da distro.
*   Copia:
    *   arquivos Waybar para `~/.config/waybar/`;
    *   `hypr-config/hyprland.conf` para `~/.config/hypr/hyprland.conf`;
    *   `mako-config/*` para `~/.config/mako/`;
    *   `wofi-config/*` para `~/.config/wofi/`.
*   Cria backup com timestamp antes de substituir arquivos existentes.
*   Normaliza caminhos antigos como `/home/watashi` para o `$HOME` do usuário instalado.
*   Marca scripts `.sh` como executáveis.
*   No final, mostra uma escolha para `Resetar interface` ou `Sair`.
    *   Em sessão Wayland com `wofi`, essa escolha aparece como menu gráfico.
    *   Em terminal puro, aparece como prompt `1/2`.
    *   `Resetar interface` reinicia o Waybar e executa `hyprctl reload` quando disponível.

## 🧩 Matriz de Pacotes por Distro

| Família | Gerenciador | Pacotes usados pelo instalador |
| --- | --- | --- |
| Arch/Endeavour/Manjaro | `pacman` | `hyprland waybar wofi mako hyprpaper kitty jq playerctl cava pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard cliphist libnotify network-manager-applet grim slurp curl hyprpicker swappy xdg-utils bluez ttf-font-awesome ttf-jetbrains-mono-nerd polkit-kde-agent` |
| Debian/Ubuntu/Mint | `apt-get` | `hyprland waybar wofi mako-notifier hyprpaper kitty jq playerctl cava pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard cliphist libnotify-bin network-manager-gnome grim slurp curl hyprpicker swappy xdg-utils bluez fonts-font-awesome fonts-jetbrains-mono polkit-kde-agent-1` |
| Fedora | `dnf` | `hyprland waybar wofi mako hyprpaper kitty jq playerctl cava pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard cliphist libnotify NetworkManager-applet grim slurp curl hyprpicker swappy xdg-utils bluez fontawesome-fonts jetbrains-mono-fonts polkit-kde` |
| openSUSE | `zypper` | `hyprland waybar wofi mako hyprpaper kitty jq playerctl cava pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard cliphist libnotify-tools NetworkManager-applet grim slurp curl hyprpicker swappy xdg-utils bluez fontawesome-fonts jetbrains-mono-fonts polkit-kde-agent-6` |
| Alpine | `apk` | `hyprland waybar wofi mako hyprpaper kitty jq playerctl cava pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard cliphist libnotify network-manager-applet grim slurp curl hyprpicker swappy xdg-utils bluez font-awesome ttf-jetbrains-mono polkit-kde-agent` |

Nem toda versão de toda distro publica Hyprland e todos os utilitários nos repositórios padrão. O instalador deixa esses casos como pendência em vez de abortar tudo.

## 📦 Modelo de Empacotamento

Este diretório agora é a raiz do pacote. Para distribuir, mantenha essa estrutura:

```text
.
├── install.sh
├── config*.jsonc
├── style.css
├── *.sh
├── hypr-config/
├── mako-config/
└── wofi-config/
```

Regras importantes:

*   Não use caminhos absolutos do seu usuário nos arquivos de origem.
*   Não versionar symlink que aponta para fora do pacote.
*   Tudo que o Hyprland chama diretamente deve existir no pacote ou ser instalado como dependência.
*   Configs externas entram em subpastas (`hypr-config`, `mako-config`, `wofi-config`) e o `install.sh` decide o destino final.

---
*Atualizado em 30/05/2026.*
