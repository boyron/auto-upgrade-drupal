#!/bin/bash

usage() {
  echo "usage: $0 

Options:
  [-c | --upgrade-core]     [optional] includes core upgrade, if any
  [-m | --merge-changes]    [optional] git merge changes with current branch
  [-h | --help]             shows this usage message

Example: $0 -c -m" 
}

strindex() { 
  x="${1%%$2*}"
  [[ $x = $1 ]] && echo -1 || echo ${#x}
}

starttime=`date +"%Y%m%d%H%M%S"`

#cd project_docroot

available_upgrades=$(drush up --pipe)
declare -a list=( $available_upgrades )

contribs2upgrade=""
dirs2add2git=""
core_upgrade_available="false"
core_upgrade_requested="false"
upgrade_core="false"
merge_changes="false"

while [ "$1" != "" ]; do
    case $1 in
        -c | --upgrade-core )   shift
                                core_upgrade_requested="true"
                                ;;
        -m | --merge-changes )  shift
                                merge_changes="true"
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

#Step 1: list projects to upgrade
##############################
for project in "${list[@]}"
do
  :
  #Check if core upgrade is available
  if [ "$project" == "drupal" ]
  then
    #Drupal core upgrade is available
    core_upgrade_available="true"
    #check argument - if upgrade_core option was checked
    if [ "$core_upgrade_requested" == "true" ]
    then
      upgrade_core="true"
    fi
    continue
  fi
  
  #get drupal directory (dd) for the project
  dd=`drush dd $project`
  
  #the script will only upgrade projects from contrib folder
  pos=$( strindex $dd contrib )
  if [ $pos -gt 1 ]
  then
    #list projects to upgrade
    contribs2upgrade="$contribs2upgrade $project"
    dirs2add2git="$dirs2add2git $dd"
  fi
done

#Exit - if there is nothing to upgrade
if [ ${#contribs2upgrade} -lt 1 ] && [ $upgrade_core == "false"]
then
  exit 2
fi

#Step 2: Create a git branch
##############################
#There is something to upgrade
#Create a git branch first 
g_b=`git branch | grep \*`
git_branch=${g_b:2}
git checkout -b Upgrade$starttime

#Step 3: Run upgrades
############
if [ ${#contribs2upgrade} -gt 1 ]
then
  #Run the upgrade command. 
  #this will optionally keep a backup of each module upgaded inside ~/drush_backups dir
  drush up $contribs2upgrade -y
  
  #git commit and push files
  git add $dirs2add2git
  git commit -m "Auto upgrade (modules) Upgrade$starttime" $dirs2add2git
fi

if [ "$upgrade_core" == "true" ]
then
  #Run core upgade
  #It will also upgrade .htaccess and robots.txt
  #@TODO shall we merge .htaccess and robots.txt modifications?
  cp robots.txt robots.txt.BAK
  cp .htaccess htaccess.BAK
  drush up drupal -y
  mv robots.txt.BAK robots.txt
  mv htaccess.BAK .htaccess

  #git commit and push files
  git add includes misc modules profiles scripts themes authorize.php cron.php index.php update.php web.config xmlrpc.php 
  git commit -m "Auto upgrade (core) Upgrade$starttime" includes misc modules profiles scripts themes authorize.php cron.php index.php update.php web.config xmlrpc.php
fi

#Step 4: Commit/Push changes
##############################
git push -u origin Upgrade$starttime

#Step 5: Merge changes
##############################
if [ "$merge_changes" == "true" ]
then
  git checkout $git_branch
  git pull
  git merge Upgrade$starttime
  git push -u origin $git_branch
fi