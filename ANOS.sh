#!/bin/bash

# ANOS - Automatic Notes Organiser Script
# Authors: Nijigokoro - nijigokoro@gmail.com

# Configuration :
ICAL_FILE_URL="" # Lien pour télécharger le fichier .ical
MATIERES_FOLDER="Matieres"
TEMPLATE_FOLDER="Template"
DATES_FOLDER="Dates"

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
 "Y8P"         `Y8    88        `Y8   `"Y8888P"`    a8P"Y88888P" 

                 Automatic Notes Organiser Script

  '
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

printHeader

if [[ ! -d "$MATIERES_FOLDER" || ! -d "$DATES_FOLDER" || ! -d "$TEMPLATE_FOLDER" ]]; then
  echo "Des répertoires sont manquant. Création.."
  mkdir -p $MATIERES_FOLDER $DATES_FOLDER $TEMPLATE_FOLDER
  echo "Veuillez relancer le programme"
  exit 1
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
wget ${ICAL_FILE_URL} -q -O "$TEMP_DIR/export.ical"

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
  NO_MATIERE_TEXT="Pas de matière"

  select matiere in "${MATIERES_ARRAY[@]}" "$NO_MATIERE_TEXT"; do
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
