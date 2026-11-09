#!/bin/bash
# Publish one Instagram post to @tinocokids.app: ./ig-post.sh posts/<name>.jpg captions/<name>.txt
# The JPEG is pushed to this public repo first, because Instagram downloads it from a public URL.
# Token: ~/tinoco-keys/instagram-token (never printed; curl reads it from the file).
set -euo pipefail
cd "$(dirname "$0")"
IMG=$1; CAP=$2; TOK=~/tinoco-keys/instagram-token
IG=17841474085225989; API=https://graph.facebook.com/v23.0
[[ $IMG == *.jpg && -f $IMG && -f $CAP && -f $TOK ]] || { echo "usage: $0 posts/x.jpg captions/x.txt (and token file)"; exit 1; }
api(){ curl -sS --data-urlencode "access_token@$TOK" "$@"; }
field(){ python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('$1') or ''); e=d.get('error'); e and sys.exit('API error: '+e.get('message',''))"; }

git add "$IMG" "$CAP"; git diff --cached --quiet || git commit -qm "Post: $(basename "$IMG" .jpg)"; git push -q origin main
URL=https://raw.githubusercontent.com/Joseflorescarmona/tinoco-social/main/$IMG
for i in $(seq 30); do [[ $(curl -so /dev/null -w '%{http_code}' "$URL") == 200 ]] && break; sleep 5; done

C=$(api --data-urlencode "image_url=$URL" --data-urlencode "caption@$CAP" "$API/$IG/media" | field id)
for i in $(seq 30); do
  S=$(api -G -d fields=status_code "$API/$C" | field status_code)
  [[ $S == FINISHED ]] && break; [[ $S == ERROR || $S == EXPIRED ]] && { echo "container $S"; exit 1; }; sleep 10
done
M=$(api -d "creation_id=$C" "$API/$IG/media_publish" | field id)
api -G -d fields=permalink "$API/$M" | field permalink
