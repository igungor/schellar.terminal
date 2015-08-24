#!/usr/bin/env bash

dir=$(dirname "$0")

gnomeVersion="$(expr "$(gnome-terminal --version)" : '.* \(.*[.].*[.].*\)$')"

# newGnome=1 if the gnome-terminal version >= 3.8
if [[ ("$(echo "$gnomeVersion" | cut -d"." -f1)" = "3" && \
       "$(echo "$gnomeVersion" | cut -d"." -f2)" -ge 8) || \
       "$(echo "$gnomeVersion" | cut -d"." -f1)" -ge 4 ]]
  then newGnome="1"
  dconfdir=/org/gnome/terminal/legacy/profiles:
else
  newGnome=0
  gconfdir=/apps/gnome-terminal/profiles
fi

to_gconf() {
    tr '\n' \: | sed 's#:$#\n#'
}

to_dconf() {
    tr '\n' '~' | sed -e "s#~\$#']\n#" -e "s#~#', '#g" -e "s#^#['#"
}

declare -a profiles
if [ "$newGnome" = "1" ]
  then profiles=($(dconf list $dconfdir/ | grep ^: | sed 's/\///g'))
else
  profiles=($(gconftool-2 -R $gconfdir | grep $gconfdir | cut -d/ -f5 |  \
           cut -d: -f1))
fi


create_new_profile() {
  profile_id="$(uuidgen)"
  dconf write $dconfdir/default "'$profile_id'"
  dconf write $dconfdir/list "['$profile_id']"
  profile_dir="$dconfdir/:$profile_id"
  dconf write $profile_dir/visible-name "'Default'"
}

get_uuid() {
  # Print the UUID linked to the profile name sent in parameter
  local profile_name=$1
  for i in ${!profiles[*]}
    do
      if [[ "$(dconf read $dconfdir/${profiles[i]}/visible-name)" == \
          "'$profile_name'" ]]
        then echo "${profiles[i]}"
        return 0
      fi
    done
  echo "$profile_name"
}

get_profile_name() {
  local profile_name

  # dconf still return "" when the key does not exist, gconftool-2 return 0,
  # but it does priint error message to STDERR, and command substitution
  # only gets STDOUT which means nothing at this point.
  if [ "$newGnome" = "1" ]
    then profile_name="$(dconf read $dconfdir/$1/visible-name | sed s/^\'// | \
        sed s/\'$//)"
  else
    profile_name=$(gconftool-2 -g $gconfdir/$1/visible_name)
  fi
  [[ -z $profile_name ]] && die "$1 (No name)" 3
  echo $profile_name
}

check_empty_profile() {
  if [ "$profiles" = "" ]
    then interactive_new_profile
    create_new_profile
    profiles=($(dconf list $dconfdir/ | grep ^: | sed 's/\///g'))
  fi
}

# extract profilename from gconf/dconf shit pile.
get_default_profile() {
  if [ "$newGnome" = "1" ]
    then profile_id="$(dconf read $dconfdir/default | \
        sed s/^\'// | sed s/\'$//)"
    profile_name="$(dconf read $dconfdir/":"$profile_id/visible-name | \
        sed s/^\'// | sed s/\'$//)"
  else
    profile_name="$(gconftool-2 -g \
        /apps/gnome-terminal/global/default_profile)"
  fi
  echo $profile_name
}

set_profile_colors() {
  local profile=${2:-"$(get_default_profile)"}

  local bg_color_file=$dir/colors/background
  local fg_color_file=$dir/colors/foreground
  local bold_color_file=$dir/colors/bold
  local palette_file=$dir/colors/palette

  if [ "$newGnome" = "1" ]
    then local profilepath=$dconfdir/$profile

    # set colors
    dconf write $profilepath/foreground-color "'$(cat $fg_color_file)'"
    dconf write $profilepath/background-color "'$(cat $bg_color_file)'"
    dconf write $profilepath/bold-color "'$(cat $bold_color_file)'"
    dconf write $profilepath/palette "$(to_dconf < $palette_file)"

    dconf write $profilepath/use-theme-colors "false"
    dconf write $profilepath/bold-color-same-as-fg "false"

  else
    local profilepath=$gconfdir/$profile

    # set colors
    gconftool-2 -s -t string $profilepath/foreground_color \
        $(cat $fg_color_file)
    gconftool-2 -s -t string $profilepath/background_color \
        $(cat $bg_color_file)
    gconftool-2 -s -t string $profilepath/bold_color $(cat $bold_color_file)
    gconftool-2 -s -t string $profilepath/palette "$(to_gconf < $palette_file)"

    gconftool-2 -s -t bool $profilepath/use_theme_colors false
    gconftool-2 -s -t bool $profilepath/bold_color_same_as_fg false
  fi
}

set_profile_colors
