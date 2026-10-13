import base64, json, os, sys, urllib.request, concurrent.futures as cf

MODEL = "gemini-3-pro-image"
STYLE = (
    "A single game UI icon, bold cartoon illustration style. "
    "Thick, continuous, uniform black outline around the entire silhouette and major inner shapes, "
    "so it stays readable when shrunk to 20 pixels. Saturated colors, cel shading with two or three "
    "flat shade steps and crisp highlights, no photorealism, no soft gradients, no text, no frame, "
    "no border, no badge, no background scenery. The subject fills about 85% of the square canvas, "
    "centered, slightly dynamic diagonal composition. "
    "Background: perfectly flat solid pure magenta (#FF00FF) everywhere outside the outline, "
    "no shadow on the background, no magenta inside the subject."
)
SUBJECTS = {
    "bm-horn":  "Subject: a curved hunting war horn made of ivory with a leather strap and a dangling beast-fang charm; a few small green leaves. Main colors: ivory, brown leather, forest green accents.",
    "bm-boar":  "Subject: the head of a snarling wild boar with big curved tusks, facing three-quarters left, fierce and loyal hunting companion. Main colors: brown and tan fur, ivory tusks, small green accents.",
    "mm-target":"Subject: a round archery target (red and cream rings) pierced dead center by a single arrow with eagle-feather fletching, arrow pointing diagonally from top-left. Main colors: red, cream, wood brown, white feathers, a small green accent.",
    "sv-bomb":  "Subject: a round black wildfire bomb with a lit orange flaming fuse, in front of a short survival hatchet with a wooden handle wrapped in red cloth, placed diagonally. Main colors: dark iron, orange fire, steel, wood brown, a small green accent.",
}

def call(key, n):
    body = {"contents": [{"parts": [{"text": STYLE + " " + SUBJECTS[key]}]}],
            "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "1:1"}}}
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(), method="POST",
        headers={"Content-Type": "application/json", "x-goog-api-key": os.environ["GEMINI_API_KEY"]})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        return f"{key}#{n}: HTTP {e.code} {e.read()[:300]}"
    for c in data.get("candidates", []):
        for p in c.get("content", {}).get("parts", []):
            if "inlineData" in p:
                fn = f"raw-{key}-{n}.png"
                open(fn, "wb").write(base64.b64decode(p["inlineData"]["data"]))
                return f"{key}#{n}: {fn}"
    return f"{key}#{n}: no image {json.dumps(data)[:300]}"

keys = sys.argv[1:] or list(SUBJECTS)
jobs = [(k, n) for k in keys for n in (1, 2)]
with cf.ThreadPoolExecutor(4) as ex:
    for res in ex.map(lambda kn: call(*kn), jobs):
        print(res)
