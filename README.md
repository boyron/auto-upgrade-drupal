auto-upgrade-drupal
===================

Upgrade script for Drupal core and contributed modules. Supports Drupal 6, Drupal 6 with Pressflow and Drupal 7.

Run following command to see the usage :)

```
$ ./auto-upgrade.sh -h
usage: ./auto-upgrade.sh

Options:
  [-p | --pressflow]        [optional] the site is in pressflow6
  [-c | --upgrade-core]     [optional] includes core upgrade, if any
  [-s | --secure-only]      [optional] only update modules which have security upgrade
  [-m | --merge-changes]    [optional] git merge changes with current branch
  [-i | --ignore-list]      [optional] ignore modules; comma separated; without space
  [-u | --uri]              [optional] in case of multi-site, provide URI. e.g.: -u blog.example.com
  [-h | --help]             shows this usage message

Example:
./auto-upgrade.sh -c -m
./auto-upgrade.sh -i "ckeditor apachesolr"
./auto-upgrade.sh -u blog.example.com
```

## Prerequisite

- You must have [drush](http://drush.ws "Drush Homepage") installed.
- Your project has to be in a git repo.
- If you are running the script from your local host, you must have proper virtual host setup for your Drupal project.
- The script has to be run from your project document root.
- Contributed modules have to be inside 'contrib' folder. e.g.: `sites/all/modules/contrib/`

## Usage

- The script will upgrade drupal contribs by default. To include drupal core upgrade add -c option.
- The script will create a git branch before attempting any upgrade and leave the branch alone by default. 
- To merge changes with the current branch, run the script with -m option.
- For example, to include core upgrade and merge at the end, run `./auto-upgrade.sh -c -m`
- When you run the script please save the output in a file. That will help you to use the log to debug any error. 
- To do so, run the script with > filename.txt option. E.g.: `./auto-upgrade.sh -s -i "ckeditor" > log.txt`


## Troubleshooting:

As we experienced the script execution for different projects, we learned few other things that need to be considered during the script run. Please also take the following into account before running the script. (in addition to the others mentioned in the previous emails)

1. Make sure that you have drush installed properly.
  1. [How to install drush](https://drupal.org/node/1791676)
  1. [How to install drush in Windows](http://kb.jaxara.com/how-install-drush-windows "How to install drush in Windows")
2. Before running the script, do a manual review.
  1. Check the available updates from administration panel or run `drush upc --pipe` to see available updates.
  1. Prepare yourself to run the script. Which options you are going to select when you run  the command. (e.g.: `./auto-upgrade.sh -i "project" -s > ../log.txt`)
   1. Check if you are going to ignore any module upgrade. 
3. Check if there are any fatal error in any modules php script. e.g.: Any syntax error, class file not included etc  
  1. We experienced one such problem in rules module during updating few projects. If the script encounters any fatal error during execution, it will be terminated in the middle of execution.
  1. To avoid this, disable any corrupted module first before running the script. To disable a module using drush, run `drush dis module_name`
4. Make sure that no file are in use or no folder is open or in use by other program when you run the script.
  1. When the script is asked to update the core (`drush up drupal`), it moves all files (including .git) to a separate directory before update. And will revert back the .git folder and sites folder after update. If any file are in use, Windows will prevent to move back the folders which will cause the script to behave weirdly.
5. Make sure that the project document root path does not have any space.
  1. A path like `/d/All gits/project/root` will not work.
  1. Make sure the folder names do not have space in it.
6. PHP memory limit shall be set to > 1024M
  1. Drush requires a higher memory limit for some commands.
  1. Make sure you changed it in the php.ini for the CLI one
7. Make sure that php exec() is not disabled.
  1. Drush requires exec() to run the commands.

  

@questions: ron@ronee.tel
