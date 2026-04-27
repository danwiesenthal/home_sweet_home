# Credit to Steve Losh!  This is mostly just based off of his excellent blog post:  http://stevelosh.com/blog/2010/02/my-extravagant-zsh-prompt/


function collapse_pwd {
    echo $(pwd | sed -e "s,^$HOME,~,")
}

function prompt_char {
    git branch >/dev/null 2>/dev/null && echo '±' && return
    hg root >/dev/null 2>/dev/null && echo '☿' && return
    echo '○'
}

function battery_charge {
    echo `~/.batcharge.py` 2>/dev/null
}

function virtualenv_info {
    [ -z "$VIRTUAL_ENV" ] && return
    local env_name=${VIRTUAL_ENV:t}
    if [ "$env_name" = ".venv" ] || [ "$env_name" = "venv" ]; then
        env_name=${VIRTUAL_ENV:h:t}
    fi
    echo "($env_name) "
}

PROMPT='
%{$fg[magenta]%}%n%{$reset_color%} at %{$fg[blue]%}%m%{$reset_color%} in %{$fg[green]%}$(collapse_pwd)%{$reset_color%}$(git_prompt_info)
$(virtualenv_info)$(prompt_char) '

RPROMPT='$(battery_charge)'

ZSH_THEME_GIT_PROMPT_PREFIX=" on %{$fg[magenta]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[green]%}!"
#ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[green]%}?"
ZSH_THEME_GIT_PROMPT_CLEAN=""
