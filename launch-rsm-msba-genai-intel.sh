#!/bin/bash

## create lock file path in user's home directory
LOCK_FILE="${HOME}/.rsm-msba-launch.lock"

## check if lock file exists
if [ -f "${LOCK_FILE}" ]; then
  echo "---------------------------------------------------------------------------"
  echo "A launch script may already be running. To close the new session and"
  echo "continue with the previous session press q + enter. To continue with"
  echo "the new session and stop the previous session, press enter"
  echo "---------------------------------------------------------------------------"
  read contd
  if [ "${contd}" == "q" ]; then
    exit 1
  fi
  rm -f "${LOCK_FILE}"
fi

## create lock file
touch "${LOCK_FILE}"

## ensure lock file is removed when script exits
trap 'rm -f "${LOCK_FILE}"; exit' INT TERM EXIT

## set ARG_HOME to a directory of your choosing if you do NOT
## want to to map the docker home directory to your local
## home directory

## use the command below on to launch the container:
## ~/git/docker-genai/launch-rsm-msba-genai-intel.sh -v ~

## to map the directory where the launch script is located to
## the docker home directory call the script_home function
script_home () {
  echo "$(echo "$( cd "$(dirname "$0")" ; pwd -P )" | sed -E "s|^/([A-z]{1})/|\1:/|")"
}

function launch_usage() {
  echo "Usage: $0 [-t tag (version)] [-d directory]"
  echo "  -t, --tag         Docker image tag (version) to use"
  echo "  -d, --directory   Project directory to use"
  echo "  -v, --volume      Volume to mount as home directory"
  echo "  -s, --show        Show all output generated on launch"
  echo "  -h, --help        Print help and exit"
  echo ""
  echo "Example: $0 -t 0.1.0 -v ~/myproject"
  echo ""
  exit 1
}

LAUNCH_ARGS="${@:1}"

## parse command-line arguments
while [[ "$#" > 0 ]]; do case $1 in
  -t|--tag) ARG_TAG="$2"; shift;shift;;
  -d|--directory) ARG_DIR="$2";shift;shift;;
  -v|--volume) ARG_VOLUME="$2";shift;shift;;
  -s|--show) ARG_SHOW="show";shift;shift;;
  -h|--help) launch_usage;shift; shift;;
  *) echo "Unknown parameter passed: $1"; echo ""; launch_usage; shift; shift;;
esac; done

## change to some other path to use as default
# ARG_HOME="~/rady"
# ARG_HOME="$(script_home)"
ARG_HOME=""
IMAGE_VERSION="latest"
NB_USER="jovyan"
ID="vnijs"
LABEL="rsm-msba-genai-intel"
NETWORK="rsm-genai"
IMAGE=${ID}/${LABEL}
# Choose your timezone https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
TIMEZONE="America/Los_Angeles"
if [ "$ARG_TAG" != "" ]; then
  IMAGE_VERSION="$ARG_TAG"
  DOCKERHUB_VERSION=${IMAGE_VERSION}
else
  ## see https://stackoverflow.com/questions/34051747/get-environment-variable-from-docker-container
  DOCKERHUB_VERSION=$(docker inspect -f '{{range $index, $value := .Config.Env}}{{println $value}} {{end}}' ${IMAGE}:${IMAGE_VERSION} | grep DOCKERHUB_VERSION)
  DOCKERHUB_VERSION="${DOCKERHUB_VERSION#*=}"
fi
POSTGRES_VERSION=16

## what os is being used
ostype=`uname`
if [ "$ostype" == "Darwin" ]; then
  EXT="command"
else
  EXT="sh"
fi

BOUNDARY="---------------------------------------------------------------------------"

if [ "$ARG_SHOW" != "show" ]; then
  clear
fi
has_docker=$(which docker)
if [ "${has_docker}" == "" ]; then
  echo $BOUNDARY
  echo "Docker is not installed. Download and install Docker from"
  if [[ "$ostype" == "Linux" ]]; then
    is_wsl=$(which explorer.exe)
    if [[ "$is_wsl" != "" ]]; then
      echo "https://hub.docker.com/editions/community/docker-ce-desktop-windows"
    else
      echo "https://docs.docker.com/engine/install/ubuntu/"
    fi
  elif [[ "$ostype" == "Darwin" ]]; then
    echo "https://hub.docker.com/editions/community/docker-ce-desktop-mac"
  else
    echo "https://hub.docker.com/editions/community/docker-ce-desktop-windows"
  fi
  echo $BOUNDARY
  read
else

  ## check docker is running at all
  ## based on https://stackoverflow.com/questions/22009364/is-there-a-try-catch-command-in-bash
  {
    docker ps -q 2>/dev/null
  } || {
    if [[ "$ostype" == "Darwin" ]]; then
      ## from https://stackoverflow.com/a/48843074/1974918
      # On Mac OS this would be the terminal command to launch Docker
      open /Applications/Docker.app
      #Wait until Docker daemon is running and has completed initialisation
      while (! docker stats --no-stream 2>/dev/null); do
        echo "Please wait while Docker starts up ..."
        sleep 2
      done
    else
      echo $BOUNDARY
      echo "Docker is not running. Please start docker on your computer"
      echo "When docker has finished starting up press [ENTER] to continue"
      echo $BOUNDARY
      read
    fi
  }

  ## kill running containers
  running=$(docker ps -a --format {{.Names}} | grep ${LABEL} -w)
  if [ "${running}" != "" ]; then
    echo $BOUNDARY
    echo "Stopping running containers"
    echo $BOUNDARY
    docker stop ${LABEL}
    docker container rm ${LABEL} 2>/dev/null
  fi

  ## download image if not available
  available=$(docker images -q ${IMAGE}:${IMAGE_VERSION})
  if [ "${available}" == "" ]; then
    echo $BOUNDARY
    echo "Downloading the ${LABEL}:${IMAGE_VERSION} computing environment"
    echo $BOUNDARY
    docker logout
    docker pull ${IMAGE}:${IMAGE_VERSION}
  fi

  chip=""
  if [[ "$ostype" == "Linux" ]]; then
    ostype="Linux"
    if [[ "$archtype" == "aarch64" ]]; then
      chip="(ARM64)"
    else
      chip="(Intel)"
    fi
    HOMEDIR=~
    ID=$USER
    open_browser () {
      xdg-open $1
    }
    sed_fun () {
      sed -i $1 "$2"
    }
    if [ -d "/media" ]; then
      MNT="-v /media:/media"
    else
      MNT=""
    fi

    is_wsl=$(which explorer.exe)
    if [[ "$is_wsl" != "" ]]; then
      archtype=`arch`
      ostype="WSL2"
      if [[ "$archtype" == "aarch64" ]]; then
        chip="(ARM64)"
      else
        chip="(Intel)"
      fi
      HOMEDIR="/mnt/c/Users/$USER"
      if [ -d "/mnt/c" ]; then
        MNT="$MNT -v /mnt/c:/mnt/c"
      fi
      if [ -d "/mnt/d" ]; then
        MNT="$MNT -v /mnt/d:/mnt/d"
      fi
    fi
  elif [[ "$ostype" == "Darwin" ]]; then
    archtype=`arch`
    ostype="macOS"
    if [[ "$archtype" == "arm64" ]]; then
      chip="(ARM64)"
    else
      chip="(Intel)"
    fi
    HOMEDIR=~
    ID=$USER
    open_browser () {
      open $1
    }
    sed_fun () {
      sed -i '' -e $1 "$2"
    }
    MNT="-v /Volumes:/media/Volumes"
  else
    archtype=`arch`
    ostype="Windows"
    if [[ "$archtype" == "aarch64" ]]; then
      chip="(ARM64)"
    else
      chip="(Intel)"
    fi
    HOMEDIR="C:/Users/$USERNAME"
    ID=$USERNAME
    open_browser () {
      start $1
    }
    sed_fun () {
      sed -i $1 "$2"
    }
    MNT=""
  fi

  if [ "$ARG_VOLUME" != "" ]; then
    HOMEDIR="$ARG_VOLUME"
  fi

  if [ "$ARG_DIR" != "" ] || [ "$ARG_HOME" != "" ]; then
    ## change mapping of docker home directory to local directory if specified
    if [ "${ARG_HOME}" != "" ] && [ ! -d "${ARG_HOME}" ]; then
      echo "The directory ${ARG_HOME} does not yet exist."
      echo "Please create the directory and restart the launch script"
      sleep 5
      exit 1
    fi
    if [ "$ARG_DIR" != "" ]; then
      if [ ! -d "${ARG_DIR}" ]; then
        echo "The directory ${ARG_DIR} does not yet exist."
        echo "Please create the directory and restart the launch script"
        sleep 5
        exit 1
      fi
      ARG_HOME="$(cd "$ARG_DIR"; pwd)"
      ## https://unix.stackexchange.com/questions/295991/sed-error-1-not-defined-in-the-re-under-os-x
      ARG_HOME="$(echo "$ARG_HOME" | sed -E "s|^/([A-z]{1})/|\1:/|")"

      echo $BOUNDARY
      echo "Do you want to access git and ssh configuration in this directory (y/n)"
      echo "${ARG_HOME}"
      echo $BOUNDARY
      read copy_config
    else
      copy_config="y"
    fi

    if [ "${copy_config}" == "y" ]; then
      if [ -f "${HOMEDIR}/.inputrc" ] && [ ! -s "${ARG_HOME}/.inputrc" ]; then
        MNT="$MNT -v ${HOMEDIR}/.inputrc:/home/$NB_USER/.inputrc"
      fi
      if [ -f "${HOMEDIR}/.gitconfig" ] && [ ! -s "${ARG_HOME}/.gitconfig" ]; then
        MNT="$MNT -v ${HOMEDIR}/.gitconfig:/home/$NB_USER/.gitconfig"
      fi
      if [ -d "${HOMEDIR}/.ssh" ]; then
        if [ ! -d "${ARG_HOME}/.ssh" ] || [ ! "$(ls -A $ARG_HOME/.ssh)" ]; then
          MNT="$MNT -v ${HOMEDIR}/.ssh:/home/$NB_USER/.ssh"
        fi
      fi
    fi

    if [ ! -f "${ARG_HOME}/.gitignore" ]; then
      ## make sure no hidden files go into a git repo
      touch "${ARG_HOME}/.gitignore"
      echo ".*" >> "${ARG_HOME}/.gitignore"
    fi

    if [ -d "${HOMEDIR}/Dropbox" ]; then
      if [ ! -d "${ARG_HOME}/Dropbox" ] || [ ! "$(ls -A $ARG_HOME/Dropbox)" ]; then
        MNT="$MNT -v ${HOMEDIR}/Dropbox:/home/$NB_USER/Dropbox"
        sed_fun '/^Dropbox$/d' "${ARG_HOME}/.gitignore"
        echo "Dropbox" >> "${ARG_HOME}/.gitignore"
      fi
    fi

    if [ -d "${HOMEDIR}/.rsm-msba" ] && [ ! -d "${ARG_HOME}/.rsm-msba" ]; then

      {
        which rsync 2>/dev/null
        HD="$(echo "$HOMEDIR" | sed -E "s|^([A-z]):|/\1|")"
        AH="$(echo "$ARG_HOME" | sed -E "s|^([A-z]):|/\1|")"
        rsync -a "${HD}/.rsm-msba" "${AH}/" --exclude R --exclude bin --exclude lib --exclude share
      } ||
      {
        cp -r "${HOMEDIR}/.rsm-msba" "${ARG_HOME}/.rsm-msba"
        rm -rf "${ARG_HOME}/.rsm-msba/bin"
        rm -rf "${ARG_HOME}/.rsm-msba/lib"
        rm_list=$(ls "${ARG_HOME}/.rsm-msba/share" | grep -v jupyter)
        for i in ${rm_list}; do
           rm -rf "${ARG_HOME}/.rsm-msba/share/${i}"
        done
      }
    fi
    SCRIPT_HOME="$(script_home)"
    if [ "${SCRIPT_HOME}" != "${ARG_HOME}" ]; then
      cp -p "$0" "${ARG_HOME}/launch-${LABEL}.${EXT}"
      sed_fun "s+^ARG_HOME\=\".*\"+ARG_HOME\=\"\$\(script_home\)\"+" "${ARG_HOME}/launch-${LABEL}.${EXT}"
      if [ "$ARG_TAG" != "" ]; then
        sed_fun "s/^IMAGE_VERSION=\".*\"/IMAGE_VERSION=\"${IMAGE_VERSION}\"/" "${ARG_HOME}/launch-${LABEL}.${EXT}"
      fi
    fi
    HOMEDIR="${ARG_HOME}"
  fi

  ## adding an dir for zsh to use
  if [ ! -d "${HOMEDIR}/.rsm-msba/zsh" ]; then
    mkdir -p "${HOMEDIR}/.rsm-msba/zsh"
  fi

  BUILD_DATE=$(docker inspect -f '{{.Created}}' ${IMAGE}:${IMAGE_VERSION})

  { 
    # check if network already exists
    docker network inspect ${NETWORK} >/dev/null 2>&1 
  } || { 
    # if network doesn't exist create it
    echo "--- Creating docker network: ${NETWORK} ---"
    docker network create ${NETWORK} 
  }

  echo $BOUNDARY
  echo "Starting the ${LABEL} computing environment on ${ostype} ${chip}"
  echo "Version   : ${DOCKERHUB_VERSION}"
  echo "Build date: ${BUILD_DATE//T*/}"
  echo "Base dir. : ${HOMEDIR}"
  echo $BOUNDARY

  has_volume=$(docker volume ls | awk "/pg_data/" | awk '{print $2}')
  if [ "${has_volume}" == "" ]; then
    docker volume create --name=pg_data
  fi
  {
    docker run --name ${LABEL} --net ${NETWORK} -d \
      -p 127.0.0.1:8765:8765 \
      -e TZ=${TIMEZONE} \
      -v "${HOMEDIR}":/home/${NB_USER} $MNT \
      -v pg_data:/var/lib/postgresql/${POSTGRES_VERSION}/main \
      ${IMAGE}:${IMAGE_VERSION}
  } || {
    echo $BOUNDARY
    echo "It seems there was a problem starting the docker container. Please"
    echo "report the issue and add a screenshot of any messages shown on screen."
    echo "Press [ENTER] to continue"
    echo $BOUNDARY
    read
  }

  show_service () {
    echo $BOUNDARY
    echo "Starting the ${LABEL} computing environment on ${ostype} ${chip}"
    echo "Version   : ${DOCKERHUB_VERSION}"
    echo "Build date: ${BUILD_DATE//T*/}"
    echo "Base dir. : ${HOMEDIR}"
    echo "Cont. name: ${LABEL}"
    echo $BOUNDARY
    echo "Press (1) to show a (ZSH) terminal, followed by [ENTER]:"
    echo "Press (2) to start N8N, followed by [ENTER]:"
    echo "Press (3) to start Playwright for Web Automation, followed by [ENTER]:"
    echo "Press (4) to setup Git and GitHub, followed by [ENTER]:"
    echo "Press (5) to update the ${LABEL} container, followed by [ENTER]:"
    echo "Press (6) to update the launch script, followed by [ENTER]:"
    echo "Press (h) to show help in the terminal and browser, followed by [ENTER]:"
    echo "Press (c) to commit changes, followed by [ENTER]:"
    echo "Press (q) to stop the docker process, followed by [ENTER]:"
    echo $BOUNDARY
    echo "Note: To start a specific container version type, e.g., 5 ${DOCKERHUB_VERSION} [ENTER]"
    echo "Note: To commit changes to the container type, e.g., c myversion [ENTER]"
    echo $BOUNDARY
    read menu_exec menu_arg

    # function to shut down running rsm containers
    clean_rsm_containers () {
      rsm_containers=$(docker ps -a --format {{.Names}} | grep "${LABEL}" | tr '\n' ' ')
      eval "docker stop $rsm_containers"
      eval "docker container rm $rsm_containers"
      docker network rm ${NETWORK}
    }

    if [ -z "${menu_exec}" ]; then
      echo "Invalid entry. Resetting launch menu ..."
    elif [ ${menu_exec} == 1 ]; then
      if [ "$ARG_SHOW" != "show" ]; then
        clear
      fi
      if [ "${menu_arg}" == "" ]; then
        zsh_lab="${LABEL}"
      else
        zsh_lab="${LABEL}-${menu_arg}"
      fi

      echo $BOUNDARY
      echo "ZSH terminal for container ${zsh_lab} of ${IMAGE}:${IMAGE_VERSION}"
      echo "Type 'exit' to return to the launch menu"
      echo $BOUNDARY
      echo ""
      ## git bash has issues with tty
      if [[ "$ostype" == "Windows" ]]; then
        winpty docker exec -it --user ${NB_USER} ${zsh_lab} sh
      else
        docker exec -it --user ${NB_USER} ${zsh_lab} /bin/zsh
      fi
    elif [ "${menu_exec}" == 2 ]; then
      echo $BOUNDARY
      echo "Starting N8N in the ${LABEL} container is not yet available"
      echo "Updates will be shared soon ..."
      echo $BOUNDARY  
      sleep 5
    elif [ "${menu_exec}" == 3 ]; then
      echo $BOUNDARY
      echo "Starting Playwright in the ${LABEL} container is not yet available"
      echo "Updates will be shared soon ..."
      echo $BOUNDARY
      sleep 5

      # if [ "${menu_arg}" != "" ]; then
      #   playwright_port=${menu_arg}
      # else 
      #   playwright_port=4444
      # fi
      # CPORT=$(curl -s localhost:${playwright_port} 2>/dev/null)
      # echo $BOUNDARY
      # playwright_nr=($(docker ps -a | awk "/rsm-playwright/" | awk '{print $1}'))
      # playwright_nr=${#playwright_nr[@]}
      # if [ "$CPORT" != "" ]; then
      #   echo "A playwright container may already be running on port ${playwright_port}"
      #   playwright_nr=$((${playwright_nr}-1))
      # else
      #   docker run --name="rsm-playwright${playwright_nr}" --net ${NETWORK} -d -p 127.0.0.1:${playwright_port}:4444 --platform linux/arm64 seleniarm/standalone-firefox
      # fi
      # echo "You can access playwright at ip: rsm-playwright${playwright_nr}, port: 4444 from the"
      # echo "${LABEL} container (rsm-playwright${playwright_nr}:4444) and ip: 127.0.0.1,"
      # echo "port: ${playwright_port} (http://127.0.0.1:${playwright_port}) from the host OS"
      # echo "Press any key to continue"
      # echo $BOUNDARY
      # read continue
    elif [ ${menu_exec} == 4 ]; then
      echo $BOUNDARY
      echo "Setup Git and Github (y/n)?"
      echo $BOUNDARY
      read github

      if [ "${github}" == "y" ]; then
        /usr/local/bin/github
      fi
 
    elif [ ${menu_exec} == 5 ]; then
      echo $BOUNDARY
      echo "Updating the ${LABEL} computing environment"
      clean_rsm_containers

      if [ "${menu_arg}" == "" ]; then
        echo "Pulling down tag \"latest\""
        VERSION=${IMAGE_VERSION}
      else
        echo "Pulling down tag ${menu_arg}"
        VERSION=${menu_arg}
      fi
      docker pull ${IMAGE}:${VERSION}
      echo $BOUNDARY
      CMD="$0"
      if [ "${menu_arg}" != "" ]; then
        CMD="$CMD -t ${menu_arg}"
      fi
      if [ "$ARG_DIR" != "" ]; then
        CMD="$CMD -d ${ARG_DIR}"
      fi
      if [ "$ARG_VOLUME" != "" ]; then
        CMD="$CMD -v ${ARG_VOLUME}"
      fi
      $CMD
      exit 1
    elif [ ${menu_exec} == 6 ]; then
      echo "Updating ${IMAGE} launch script"
      clean_rsm_containers
      if [ -d "${HOMEDIR}/Desktop" ]; then
        SCRIPT_DOWNLOAD="${HOMEDIR}/Desktop"
      else
        SCRIPT_DOWNLOAD="${HOMEDIR}"
      fi
      {
        current_dir=$(pwd)
        cd ~/git/docker-genai 2>/dev/null;
        git pull 2>/dev/null;
        cd $current_dir
        chmod 755 ~/git/docker-genai/launch-${LABEL}.sh 2>/dev/null;
        rm -f "${LOCK_FILE}"
        eval "~/git/docker-genai/launch-${LABEL}.sh ${LAUNCH_ARGS}"
        exit 1
        sleep 10
      } || {
        echo "Updating the launch script failed\n"
        echo "Copy the code below and run it after stopping the docker container with q + Enter\n"
        echo "rm -rf ~/git/docker-genai;\n"
        echo "git clone https://github.com/radiant-ai-hub/docker-genai.git ~/git/docker-genai;\n"
        echo "\nPress any key to continue"
        read any_to_continue
      }
    elif [ "${menu_exec}" == "h" ]; then
      echo $BOUNDARY
      echo "Showing help for your OS in the default browser"
      echo ""
      if [[ "$ostype" == "macOS" ]]; then
        if [[ "$archtype" == "arm64" ]]; then
          open_browser https://github.com/radiant-ai-hub/docker-genai/blob/main/install/rsm-msba-macos-arm.md
        else
          open_browser https://github.com/radiant-ai-hub/docker-genai/blob/main/install/rsm-msba-macos.md
        fi
      elif [[ "$ostype" == "WSL2" ]]; then
        if [[ "$archtype" == "aarch64" ]]; then
          open_browser https://github.com/radiant-ai-hub/docker-genai/blob/main/install/rsm-msba-windows-arm.md
        else
          open_browser https://github.com/radiant-ai-hub/docker-genai/blob/main/install/rsm-msba-windows.md
        fi
      elif [[ "$ostype" == "ChromeOS" ]]; then
        open_browser https://github.com/radiant-ai-hub/docker-genai/blob/main/install/rsm-msba-chromeos.md
      else
        open_browser https://github.com/radiant-ai-hub/docker-genai/blob/main/install/rsm-msba-linux.md
      fi
      echo "Press any key to continue"
      read continue
    elif [ "${menu_exec}" == "c" ]; then
      container_id=($(docker ps -a | awk "/${ID}\/${LABEL}/" | awk '{print $1}'))
      if [ "${menu_arg}" == "" ]; then
        echo $BOUNDARY
        echo "Are you sure you want to over-write the current image (y/n)?"
        echo $BOUNDARY
        read menu_commit
        if [ "${menu_commit}" == "y" ]; then
          echo $BOUNDARY
          echo "Committing changes to ${IMAGE}"
          echo $BOUNDARY
          docker commit ${container_id[0]} ${IMAGE}:${IMAGE_VERSION}
        else 
          return 1
        fi
        IMAGE_DHUB=${IMAGE}
      else
        menu_arg="${LABEL}-$(echo -e "${menu_arg}" | tr -d '[:space:]')"
        docker commit ${container_id[0]} $ID/${menu_arg}:${IMAGE_VERSION}

        if [ -d "${HOMEDIR}/Desktop" ]; then
          SCRIPT_COPY="${HOMEDIR}/Desktop"
        else
          SCRIPT_COPY="${HOMEDIR}"
        fi
        cp -p "$0" "${SCRIPT_COPY}/launch-${menu_arg}.${EXT}"
        sed_fun "s+^ID\=\".*\"+ID\=\"${ID}\"+" "${SCRIPT_COPY}/launch-${menu_arg}.${EXT}"
        sed_fun "s+^LABEL\=\".*\"+LABEL\=\"${menu_arg}\"+" "${SCRIPT_COPY}/launch-${menu_arg}.${EXT}"

        echo $BOUNDARY
        echo "Committing changes to ${ID}/${menu_arg}"
        echo "Use the following script to launch:"
        echo "${SCRIPT_COPY}/launch-${menu_arg}.${EXT}"
        echo $BOUNDARY
        IMAGE_DHUB=${ID}/${menu_arg}
      fi

      echo $BOUNDARY
      echo "Do you want to push this image to Docker hub (y/n)?"
      echo "Note: This requires an account at https://hub.docker.com/"
      echo "Note: To specify a version tag type, e.g., y 0.1.0"
      echo $BOUNDARY
      read menu_push menu_tag
      if [ "${menu_push}" == "y" ]; then
        {
          docker login
          if [ "${menu_tag}" == "" ]; then
            docker push ${IMAGE_DHUB}:latest
          else
            if [ "${menu_arg}" == "" ]; then
              sed_fun "s/^IMAGE_VERSION=\".*\"/IMAGE_VERSION=\"${menu_tag}\"/" "$0"
            else
              sed_fun "s/^IMAGE_VERSION=\".*\"/IMAGE_VERSION=\"${menu_tag}\"/" "${SCRIPT_COPY}/launch-${menu_arg}.${EXT}"
            fi
            # echo 'docker commit --change "ENV DOCKERHUB_VERSION=${menu_tag}" ${container_id[0]} ${IMAGE_DHUB}:${menu_tag}'
            docker commit --change "ENV DOCKERHUB_VERSION=${menu_tag}" ${container_id[0]} ${IMAGE_DHUB}:${menu_tag}
            docker push ${IMAGE_DHUB}:${menu_tag}
          fi
        } || {
          echo $BOUNDARY
          echo "It seems there was a problem with login or pushing to Dockerhub"
          echo "Please make sure you have an account at https://hub.docker.com/"
          echo $BOUNDARY
          sleep 3s
        }
      fi
    elif [ "${menu_exec}" == "q" ]; then
      echo $BOUNDARY
      echo "Stopping the ${LABEL} computing environment and cleaning up as needed"
      echo $BOUNDARY

      playwright_containers=$(docker ps -a --format {{.Names}} | grep 'playwright' | tr '\n' ' ')
      if [ "${playwright_containers}" != "" ]; then
        echo "Stopping playwright containers ..."
        eval "docker stop $playwright_containers"
        eval "docker container rm $playwright_containers"
      fi

      clean_rsm_containers

      imgs=$(docker images | awk '/<none>/ { print $3 }')
      if [ "${imgs}" != "" ]; then
        echo "Removing unused containers ..."
        docker rmi -f ${imgs}
      fi

      # procs=$(docker ps -a -q --no-trunc)
      # if [ "${procs}" != "" ]; then
      #   echo "Stopping docker processes ..."
      #   docker rm ${procs}
      # fi
    else
      echo "Invalid entry. Resetting launch menu ..."
    fi

    if [ "${menu_exec}" == "q" ]; then
      ## removing empty files and directories created after -v mounting
      if [ "$ARG_HOME" != "" ]; then
        echo "Removing empty files and directories ..."
        find "$ARG_HOME" -empty -type d -delete
        find "$ARG_HOME" -empty -type f -delete
      fi
      return 2
    else
      return 1
    fi
  }

  ## sleep to give the server time to start up fully
  sleep 2
  show_service
  ret=$?
  ## keep asking until quit
  while [ $ret -ne 2 ]; do
    sleep 2
    if [ "$ARG_SHOW" != "show" ]; then
      clear
    fi
    show_service
    ret=$?
  done
fi
