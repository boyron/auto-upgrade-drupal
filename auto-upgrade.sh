#!/bin/bash

usage() {
  echo "usage: $0 

Options:
  [-p | --pressflow]        [optional] the site is in pressflow6
  [-c | --upgrade-core]     [optional] includes core upgrade, if any
  [-s | --secure-only]      [optional] only update modules which have security upgrade
  [-m | --merge-changes]    [optional] git merge changes with current branch
  [-i | --ignore-list]      [optional] ignore modules; comma separated; without space
  [-u | --uri]              [optional] in case of multi-site, provide URI. e.g.: -u blog.example.com
  [-h | --help]             shows this usage message

Example: 
$0 -c -m
$0 -i \"ckeditor apachesolr\"
$0 -u blog.example.com"
}

strindex() { 
  x="${1%%$2*}"
  [[ $x = $1 ]] && echo -1 || echo ${#x}
}

starttime=`date +"%Y%m%d%H%M%S"`
dbstring=`drush status --user=1 | grep "Database name"`
project_db_name=${dbstring:36}
drupal_version_string=`drush status --user=1 | grep "Drupal version"`
drupal_version=${drupal_version_string:36}
drupal_version_major=${drupal_version:0:1}

#cd project_docroot

contribs2upgrade=""
dirs2add2git=""
core_upgrade_available="false"
core_upgrade_requested="false"
upgrade_core="false"
merge_changes="false"
ignore_list=""
secure_upgrade_only="false"
pressflow="false"
uri=""

while [ "$1" != "" ]; do
    case $1 in
        -i | --ignore-list )    ignore_list=$2 
                                shift 2
                                ;;                  
        -p | --pressflow )      shift
                                pressflow="true"
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
        -u | --uri )            uri=$2
                                shift 2
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

upgrade_pressflow() {
  wget --no-check-certificate https://github.com/pressflow/6/archive/master.zip
  unzip master
  mkdir -p ~/drush-backups/$project_db_name/$starttime/pressflow
  cp -r * ~/drush-backups/$project_db_name/$starttime/pressflow/

  rm -r includes misc modules profiles scripts themes

  mv 6-master/* ./

  rm master
  drush updb --user=1 -y
}

uri_arg=""
if [ ${#uri} -gt 1 ]
then
  uri_arg="--uri=$uri"
fi
#echo $uri_arg
#echo "pressflow=$pressflow"
#echo "core_upgrade_requested=$core_upgrade_requested"
#echo "secure_upgrade_only=$secure_upgrade_only"
#echo "merge_changes=$merge_changes"
#echo "ignore_list=$ignore_list"
#exit 2
available_upgrades=$(drush upc $uri_arg --user=1 --pipe)
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
  dd=`drush dd $project $uri_arg --user=1`
  
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
if [ ${#contribs2upgrade} -lt 1 ] && [ $upgrade_core == "false" ]
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
  drush up $contribs2upgrade $upcmdoptions $uri_arg --user=1 -y
  
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
  if [ "$pressflow" == "true" ]
  then
    upgrade_pressflow
  else
    drush up drupal $upcmdoptions $uri_arg --user=1 -y
  fi
  mv robots.txt.BAK robots.txt
  mv htaccess.BAK .htaccess

  #git commit and push files

  if [ $drupal_version_major == "6" ]; then
    git add includes misc modules profiles scripts themes cron.php index.php update.php xmlrpc.php 
    git commit -m "Auto upgrade (core) Upgrade$starttime" includes misc modules profiles scripts themes cron.php index.php update.php xmlrpc.php
  else
    git add includes misc modules profiles scripts themes authorize.php cron.php index.php update.php web.config xmlrpc.php 
    git commit -m "Auto upgrade (core) Upgrade$starttime" includes misc modules profiles scripts themes authorize.php cron.php index.php update.php web.config xmlrpc.php
  fi
fi

#Step 4: Commit/Push changes
##############################
git push -u origin Upgrade$starttime

#Step 5: Merge changes
##############################
if [ "$merge_changes" == "true" ]
then
  git checkout $git_branch
  git branch -u origin $git_branch
  git pull
  git merge Upgrade$starttime
  git push -u origin $git_branch
fi

