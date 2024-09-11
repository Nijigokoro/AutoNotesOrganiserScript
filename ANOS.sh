#!/bin/bash

# ANOS - Automatic Notes Organiser Script
# Authors: Nijigokoro - nijigokoro@gmail.com
#

printHeader() {
  clear
  echo '
             ,ggg,  ,ggg, ,ggggggg,     _,gggggg,_          ,gg,   
          dP""8I dP""Y8,8P"""""Y8b  ,d8P""d8P"Y8b,       i8""8i  
         dP   88 Yb, `8dP`     `88 ,d8`   Y8   "8b,dP    `8,,8`  
        dP    88  `"  88`       88 d8`    `Ybaaad88P`     `88`   
       ,8`    88      88        88 8P       `""""Y8       dP"8,  
       d88888888      88        88 8b            d8      dP` `8a 
 __   ,8"     88      88        88 Y8,          ,8P     dP`   `Yb
dP"  ,8P      Y8      88        88 `Y8,        ,8P` _ ,dP`     I8
Yb,_,dP       `8b,    88        Y8, `Y8b,,__,,d8P`  "888,,____,dP
"Y8P"         `Y8    88        `Y8   `"Y8888P"`    a8P"Y88888P"' "$CURRENT_VER" '

                 Automatic Notes Organiser Script

  '
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CURRENT_VER="1.2"

printHeader

if [[ ! -e "ANOS.conf" ]]; then
  ICAL_FILE_URL=""
  MATIERES_FOLDER=""
  DATES_FOLDER=""
  echo "Fichier de configuration non trouvé.."
  echo
  while [[ ! $ICAL_FILE_URL || $ICAL_FILE_URL == "" ]]; do
    read -r -p "URL de votre calendrier > " ICAL_FILE_URL
  done

  read -r -p "Nom du dossier où les matières seront stoquées (Matieres) >" MATIERES_FOLDER
  if [[ ! $MATIERES_FOLDER || $MATIERES_FOLDER == "" ]]; then
    MATIERES_FOLDER="Matieres"
  fi

  read -r -p "Nom du dossier où les dates seront stoquées (Dates) >" DATES_FOLDER
  if [[ ! $DATES_FOLDER || $DATES_FOLDER == "" ]]; then
    DATES_FOLDER="Dates"
  fi

  read -r -p "Nom du dossier où votre template est stoqué (Template) >" TEMPLATE_FOLDER
  if [[ ! $TEMPLATE_FOLDER || $TEMPLATE_FOLDER == "" ]]; then
    TEMPLATE_FOLDER="Template"
  fi

  {
    printf "ICAL_FILE_URL=%s\n" "$ICAL_FILE_URL"
    printf "MATIERES_FOLDER=%s\n" "$MATIERES_FOLDER"
    printf "DATES_FOLDER=%s\n" "$DATES_FOLDER"
    printf "TEMPLATE_FOLDER=%s\n" "$TEMPLATE_FOLDER"
    printf "CHECK_UPDATES=1"
  } >>"ANOS.conf"
  echo "Configuration terminée."
fi

source "ANOS.conf"

if [[ ! -d "$MATIERES_FOLDER" || ! -d "$DATES_FOLDER" || ! -d "$TEMPLATE_FOLDER" ]]; then
  echo "Des répertoires sont manquant. Création.."
  mkdir -p "$MATIERES_FOLDER" "$DATES_FOLDER" "$TEMPLATE_FOLDER"
  echo "Les répertoires ont été créés. Merci de créer un dossier par matière (Maths, Chimie par exemple) dans le dossier $MATIERES_FOLDER/"
  exit 0
fi

if [[ "$CHECK_UPDATES" == 1 ]]; then
  LAST_VER=$(curl -s "https://api.github.com/repos/nijigokoro/AutoNotesOrganiserScript/releases/latest" | grep "tag_name" | cut -d'"' -f 4)
  if [[ "$CURRENT_VER" != "$LAST_VER" ]]; then
    READ=""
    echo "Une mise à jour est disponible. Voulez vous la télécharger?"
    printf "[y/N] > "
    read -r -N 1 READ
    echo
    if [[ "$READ" == "y" ]]; then
      echo "Téléchargement..."
      wget "https://github.com/Nijigokoro/AutoNotesOrganiserScript/releases/download/${LAST_VER}/ANOS.sh" -O "ANOS.sh"
      echo "Téléchargement terminé. Veuillez relancer le programme"
      exit
    fi
  fi
fi

cd "$MATIERES_FOLDER" || exit 1
mkdir -p "SansMatiere"
MATIERES_ARRAY=(*/)

TEMP_DIR=$(mktemp -d)
if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
  echo "Le programme n'a pas pu créé de fichier temporaire"
  exit 1
fi
cd ..

function cleanup {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

DATE_STRING=$(date "+%A %d %b")
DATE_STRING=${DATE_STRING%?}
DATE_STRING=${DATE_STRING^}

echo "Téléchargement de l'EDT.."
wget "${ICAL_FILE_URL}" -q -O "$TEMP_DIR/export.ical"

echo "Nous sommes le ${DATE_STRING}. Recherche d'évenements"
echo

SUMMARIES_FILE="$TEMP_DIR/summaries"
grep -A2 -B4 "DTSTART:$(date '+%Y%m%d')" "$TEMP_DIR/export.ical" >"$TEMP_DIR/events"
grep "SUMMARY:" "$TEMP_DIR/events" >"$SUMMARIES_FILE"

handle_event() {
  local EVENT_NAME_UNPROCESSED=$1

  local EVENT_NAME_WITH_SPACES=${EVENT_NAME_UNPROCESSED#*:}
  EVENT_NAME_WITH_SPACES=$(echo "$EVENT_NAME_WITH_SPACES" | tr -s '[:space:]')
  EVENT_NAME_WITH_SPACES=${EVENT_NAME_WITH_SPACES%?}

  local EVENT_NAME
  EVENT_NAME=$(echo "$EVENT_NAME_WITH_SPACES" | tr -d '[:space:]')
  echo "$EVENT_NAME_WITH_SPACES"
  echo

  PS3="De quelle matière est ce cours? "
  NO_MATIERE_TEXT="Ne pas créer de notes pour ce cours"

  select matiere in "$NO_MATIERE_TEXT" "${MATIERES_ARRAY[@]}"; do
    if [[ "$matiere" == "$NO_MATIERE_TEXT" ]]; then
      printHeader
      break
    fi

    matiere=${matiere%?}
    NOTES_DIR="$MATIERES_FOLDER/${matiere}/Notes"
    DATE_DIR="$NOTES_DIR/$DATE_STRING"
    mkdir -p "$DATE_DIR"

    j=1
    NOTE_STORAGE_DIR="$DATE_DIR/$EVENT_NAME-$i"
    while [[ -d "$NOTE_STORAGE_DIR" ]]; do
      j=$((i + 1))
      NOTE_STORAGE_DIR=${NOTE_STORAGE_DIR%-*}
      NOTE_STORAGE_DIR="$DATE_DIR/$EVENT_NAME-$j"
    done

    mkdir "$NOTE_STORAGE_DIR"
    cp -R "$TEMPLATE_FOLDER"/* "$NOTE_STORAGE_DIR/"
    DATE_DIR="$DATES_FOLDER/$DATE_STRING"
    mkdir -p "$DATE_DIR"
    ln -s "../../$NOTE_STORAGE_DIR/" "$DATE_DIR/$EVENT_NAME"
    cd "$NOTE_STORAGE_DIR" || exit
    chmod +x templateSetup.sh
    ./templateSetup.sh
    cd "$SCRIPT_DIR" || exit

    printHeader
    break
  done
}

i=1
while true; do
  EVENT_NAME_UNPROCESSED=$(sed "${i}p;d" "$SUMMARIES_FILE")
  if [[ ! "$EVENT_NAME_UNPROCESSED" ]]; then
    break
  fi
  handle_event "$EVENT_NAME_UNPROCESSED"
  i=$((i + 1))
done

echo "Merci d'avoir utilisé ANOS. Passez une bonne journée!"
