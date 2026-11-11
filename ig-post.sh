#!/bin/bash
# Publish one Instagram post to @tinocokids.app: ./ig-post.sh posts/<name>.jpg captions/<name>.txt
# Reel: ./ig-post.sh reels/<name>.mp4 captions/<name>.txt (TRIAL=1: trial Reel, needs more followers than we have yet)
# Story: STORY=1 ./ig-post.sh reels/<name>.mp4 captions/<name>.txt (the caption is not shown on Stories)
# Carousel: ./ig-post.sh posts/<name>-1.jpg captions/<name>.txt posts/<name>-2.jpg ... (2-10 images)
# The JPEG is pushed to this public repo first, because Instagram downloads it from a public URL.
# Token: ~/tinoco-keys/instagram-token (never printed; curl reads it from the file).
set -euo pipefail
cd "$(dirname "$0")"
IMG=$1; CAP=$2; MORE=("${@:3}"); TOK=~/tinoco-keys/instagram-token
IG=17841474085225989; API=https://graph.facebook.com/v23.0
[[ $IMG == *.jpg || $IMG == *.mp4 ]] && [[ -f $IMG && ${#MORE[@]} -le 9 && -f $CAP && -f $TOK ]] || { echo "usage: $0 posts/x.jpg captions/x.txt (and token file)"; exit 1; }
api(){ curl -sS --data-urlencode "access_token@$TOK" "$@"; }
field(){ python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('$1') or ''); e=d.get('error'); e and sys.exit('API error: '+e.get('message',''))"; }

git add "$IMG" ${MORE[@]+"${MORE[@]}"} "$CAP" alt; git diff --cached --quiet || git commit -qm "Post: $(basename "$IMG" .jpg)"; git push -q origin main
raw(){ local u=https://raw.githubusercontent.com/Joseflorescarmona/tinoco-social/main/$1
  for i in $(seq 30); do [[ $(curl -so /dev/null -w '%{http_code}' "$u") == 200 ]] && break; sleep 5; done; echo "$u"; }
ready(){ for i in $(seq 30); do
  S=$(api -G -d fields=status_code "$API/$1" | field status_code)
  [[ $S == FINISHED ]] && return; [[ $S == ERROR || $S == EXPIRED ]] && { echo "container $S"; exit 1; }; sleep 10; done; }
ALT=alt/$(basename "$CAP" .txt).txt; ALTARG=(); [[ -f $ALT ]] && ALTARG=(--data-urlencode "alt_text@$ALT")
if (( ${#MORE[@]} )); then
  KIDS=""; for f in "$IMG" "${MORE[@]}"; do
    K=$(api --data-urlencode "image_url=$(raw "$f")" -d is_carousel_item=true ${ALTARG[@]+"${ALTARG[@]}"} "$API/$IG/media" | field id); ready "$K"; KIDS+=${KIDS:+,}$K; done
  C=$(api -d media_type=CAROUSEL --data-urlencode "children=$KIDS" --data-urlencode "caption@$CAP" "$API/$IG/media" | field id)
elif [[ $IMG == *.mp4 ]]; then
  TRIALARG=(); [[ ${TRIAL:-} == 1 ]] && TRIALARG=(--data-urlencode 'trial_params={"graduation_strategy":"SS_PERFORMANCE"}')
  KIND=REELS; [[ ${STORY:-} == 1 ]] && { KIND=STORIES; TRIALARG=(); }
  C=$(api -d media_type=$KIND --data-urlencode "video_url=$(raw "$IMG")" --data-urlencode "caption@$CAP" ${TRIALARG[@]+"${TRIALARG[@]}"} "$API/$IG/media" | field id)
else
  C=$(api --data-urlencode "image_url=$(raw "$IMG")" --data-urlencode "caption@$CAP" ${ALTARG[@]+"${ALTARG[@]}"} "$API/$IG/media" | field id)
fi
ready "$C"
M=$(api -d "creation_id=$C" "$API/$IG/media_publish" | field id)
api -G -d fields=permalink "$API/$M" | field permalink
