# vim's pattern-searches-ish of the edit buffer for zsh.

# Author: Takeshi Banse <takebi@laafc.net>
# License: BSD-3

# Thank you very much nakamuray!
# Especally to highlight the matches, I appreciate the zaw's `filter-select`
# code a lot.

# Code

bindkey -N en emacs

typeset -g en_buffer en_keys
typeset -gi en_backward_p; ((en_backward_p = 0))
typeset -gi en_repeat_p; ((en_repeat_p = 0))

with-en () {
  local -a en_region_highlight; en_region_highlight=()
  local -i en_cursor; ((en_cursor = CURSOR))
  {
    setopt localoptions extendedglob no_ksharrays no_kshzerosubscript
    local nl=$'\n'
    local old_predisplay="$PREDISPLAY"
    local PREDISPLAY="${old_predisplay}$BUFFER${nl}"
    local POSTDISPLAY=
    local -a rh; rh=(${region_highlight[@]})
    local -a region_highlight tmp
    local hi; for hi in ${rh[@]}; do
      if [[ "${hi}" == P* ]]; then
        en_region_highlight+="${hi}"
      else
        : ${(A)tmp::=${=hi}}
        en_region_highlight+="P$(($tmp[1]+$#old_predisplay)) $(($tmp[2]+$#old_predisplay)) $tmp[3]"
      fi
    done
    region_highlight=(${en_region_highlight})
    if ((en_backward_p == 0)); then
      PREDISPLAY+='/'
    else
      PREDISPLAY+='?'
    fi
    "$@"
  } always {
    ((CURSOR = en_cursor))
  }
}

en-recursive-edit () {
  local BUFFER="$1"
  [[ -n "$BUFFER" ]] && {
    en-maybe en-movecursor
    ((en_repeat_p = 1))
  }
  zle recursive-edit -K en && {
    en_buffer="$BUFFER"
  } || {
  }
}
zle -N en-recursive-edit

() {
  setopt localoptions no_ksharrays
  local -a tmp
  # XXX: This is not accurate though.
  : ${(A)tmp::=${(f)"$(zle -l -L)"}}
  ((${tmp[(i)*-by-keymap]} < $#tmp))
} || {
  autoload -Uz keymap+widget && keymap+widget || {
    echo "en.zsh:error; sorry, en.zsh doesn't work." >&2; return -1
  }
}

en+self-insert () {
  region_highlight=(${en_region_highlight[@]})
  ((en_repeat_p == 0)) && zle .self-insert
  ((en_repeat_p == 0)) && { en-maybe ; return $? }
  ((en_repeat_p == 1)) && {
    if [[ "$KEYS" == "$en_keys" ]]; then
      en-maybe en-movecursor ; return $?
    elif [[ "${(L)KEYS}" == "$en_keys" ]]; then
      ((en_repeat_p = 1))
      ((en_backward_p = ((en_backward_p == 1 ? 0 : 1))))
      if ((en_backward_p == 0)); then
        PREDISPLAY[-1]='/'
      else
        PREDISPLAY[-1]='?'
      fi
      en-maybe en-movecursor ; return $?
    else
      zle -U "$KEYS" ; zle .accept-line ; return $?
    fi
  }
}
zle -N en+self-insert
en+backward-delete-char () { region_highlight=(${en_region_highlight[@]}) ;  zle .backward-delete-char && en-maybe }
zle -N en+backward-delete-char

en-maybe () {
  [[ -n "${BUFFER}" ]] || return -1
  setopt localoptions no_ksharrays no_kshzerosubscript
  local kont="${1-}"
  local -a match mbegin mend
  local -a rh
  local null=$'\0' nl=$'\n'
  rh=(${${(0)${(S)PREDISPLAY//*(#b)(${~BUFFER})/P$((mbegin[1]-1)) $(($mend[1])) fg=black,bg=white,standout,bold${null}}}:#*$nl*})
  if (($#rh == 0)) || (($#rh == 1)) && [[ -z "$rh" ]]; then
    return -1
  fi
  local -a param
  if ((en_backward_p == 0)); then
    param=('>=' 0 $#rh '++' '<' 1)
  else
    param=('<' $(($#rh+1)) 1 '--' '>' $#rh)
  fi
  () {
    local -a tmp
    local cmp="$1"
    local -i i=$2 to=$3 n=0 wrapped=$6 tmp_cur=$en_cursor
    local succ="$4" till="$5"
    while :; do
      while ((i$succ $till to)); do
        ((n=${${rh[i]%% *}[2,-1]}-1))
        if ((n $cmp en_cursor)); then
          : ${(A)tmp::=${=rh[i]}}
          ((tmp_cur = $en_cursor))
          [[ -n "${kont-}" ]] && { "$kont" $((n+1)) }
          ((en_repeat_p == 0)) || \
          { ((en_repeat_p == 1)) && ((en_cursor != tmp_cur)) } && {
            rh[i]="$tmp[1] $tmp[2] fg=black,bg=255"
            break 2
          }
        fi
      done
      : ${(A)tmp::=${=rh[$wrapped]}}
      rh[wrapped]="$tmp[1] $tmp[2] fg=black,bg=255"
      [[ -n "${kont-}" ]] && { "$kont" $((${${tmp[1]}[2,-1]})) }
      break
    done
  } $param[@]
  region_highlight+=(${rh[@]})
}

en+accept-line () {
  ((en_repeat_p == 0)) && en-maybe en-movecursor
  zle .accept-line
}
en-movecursor () { ((en_cursor = $1)) }

zle -N en+accept-line
bindkey -M en "^M" en+accept-line
bindkey -M en "^[" send-break
bindkey -M en "^[^[" send-break

en () { en-aux }
en-aux () {
  ((en_repeat_p = 0))
  en_keys="$KEYS"
  case "$en_keys" in
    N)
      ((en_repeat_p = 1))
      ((en_backward_p = ((en_backward_p == 1 ? 0 : 1))))
      with-en en-recursive-edit "$en_buffer"
    ;;
    n)
      ((en_repeat_p = 1))
      with-en en-recursive-edit "$en_buffer"
    ;;
    '?')
      ((en_backward_p = 1))
    ;|
    '/')
      ((en_backward_p = 0))
    ;|
    *)
      with-en en-recursive-edit ""
    ;;
  esac
}
zle -N en

bindkey -M vicmd '/' en
bindkey -M vicmd '?' en
bindkey -M vicmd 'n' en
bindkey -M vicmd 'N' en

() {
  setopt localoptions no_ksharrays
  local -a tmp; zstyle -a ':auto-fu:var' track-keymap-skip tmp
  ((${tmp[(i)en]} < $#tmp)) || {
    zstyle ':auto-fu:var' track-keymap-skip ${tmp[@]} en
  }
}
