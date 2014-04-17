#!/bin/bash

usage() {
  echo "usage: $0 

Options:
  [-c | --upgrade-core]     [optional] includes core upgrade, if any
  [-s | --secure-only]      [optional] only update modules which have security upgrade
  [-m | --merge-changes]    [optional] git merge changes with current branch
  [-i | --ignore-list]      [optional] ignore modules
  [-h | --help]             shows this usage message

Example: 
$0 -c -m
$0 -i \"ckeditor apachesolr\"" 
}

strindex() { 
  x="${1%%$2*}"
  [[ $x = $1 ]] && echo -1 || echo ${#x}
}

starttime=`date +"%Y%m%d%H%M%S"`

#cd project_docroot

contribs2upgrade=""
dirs2add2git=""
core_upgrade_available="false"
core_upgrade_requested="false"
upgrade_core="false"
merge_changes="false"
ignore_list=""
secure_upgrade_only="false"

while [ "$1" != "" ]; do
    case $1 in
        -i | --ignore-list )    ignore_list=$2 
                                shift 2
                                ;;                  
        -c | --upgrade-core )   shift
                                core_upgrade_requested="true"
                                ;;
        -s | --secure-only )    shift
                                secure_upgrade_only="true"
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
done

project_is_in_ignore_list() {

  #No Ignore list? return false
  if [ ${#ignore_list} -lt 1 ]
  then
    echo "false"
  fi

  prj=$1

  p=$( strindex $ignore_list $prj )
  if [ $p -gt -1 ]
  then
    echo "true"
  else
    echo "false"
  fi
}

available_upgrades=$(drush up --pipe)
declare -a list=( $available_upgrades )

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

  #Check if developer wants to ignore this project upgrade
  ignore=$( project_is_in_ignore_list $project)
  if [ "$ignore" == "true" ]
  then
    continue
  fi

  #Always ignore ckeditor
  if [ "$project" == "ckeditor" ]
  then
    continue
  fi

  #Google analytics module name conflict fix
  if [ "$project" == "google_analytics" ]
  then
    project="googleanalytics"
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

upcmdoptions=""
if [ "$secure_upgrade_only" == "true" ]
then
  upcmdoptions=" --security-only"
fi

#Step 2: Create a git branch
##############################
#There is something to upgrade
#Create a git branch first 
g_b=`git branch | grep \*`
git_branch=${g_b:2}
git checkout -b Upgrade$starttime

#Step 3: Run upgrades
##############################
if [ ${#contribs2upgrade} -gt 1 ]
then
  #Run the upgrade command. 
  #this will optionally keep a backup of each module upgaded inside ~/drush_backups dir
  drush up $contribs2upgrade $upcmdoptions -y
  
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
  drush up drupal $upcmdoptions -y
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

