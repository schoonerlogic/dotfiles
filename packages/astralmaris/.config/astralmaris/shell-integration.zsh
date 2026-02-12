#!/bin/zsh

VALID_AGENTS=(merlin aleph thales luban proteus)

detect_agent() {
    local dir="$PWD"
    
    if [[ -f "$dir/.helix/config.toml" ]]; then
        local theme=$(grep '^theme' "$dir/.helix/config.toml" 2>/dev/null | sed 's/.*= *"//' | tr -d '"')
        local agent=${theme#astralmaris-}
        [[ -n "$agent" ]] && echo "$agent" && return 0
    fi
    
    for a in $VALID_AGENTS; do
        if [[ "$dir" == *"-$a"* || "$dir" == *"/$a"* ]]; then
            echo "$a" && return 0
        fi
    done
}

astral_chpwd() {
    local agent=$(detect_agent)
    if [[ -n "$agent" && "$ASTRAL_LAST_AGENT" != "$agent" ]]; then
        local symbol="⟡"
        local color="\033[38;5;"
        case "$agent" in
            merlin)  color+="141m" ;;
            aleph)   color+="120m" ;;
            luban)   color+="208m" ;;
            thales)  color+="111m" ;;
            proteus) color+="250m" ;;
        esac
        echo -e "${color}${symbol} ${agent}\033[0m"
        export ASTRAL_LAST_AGENT="$agent"
    fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd astral_chpwd
astral_chpwd
