Class TestOps.Py.NLP
{

ClassMethod Fingerprint(message As %String, stacktrace As %String) As %String [ Language = python ]
{
import re, hashlib
text = (message or "") + "\n" + (stacktrace or "")
# normalize: remove line numbers, hex, paths, ids
text = re.sub(r":\d+", ":<n>", text)
text = re.sub(r"\b0x[0-9a-fA-F]+\b", "0x<hex>", text)
text = re.sub(r"[A-Za-z]:\\\\[^\\s]+", "<path>", text)
text = re.sub(r"/[^\\s]+", "<path>", text)
text = re.sub(r"\b\d+\b", "<n>", text)
text = text.lower().strip()
h = hashlib.sha256(text.encode("utf-8")).hexdigest()
return h[:32]
}

ClassMethod SimilarFingerprints(targetFp As %String, rows As %DynamicArray) As %DynamicArray [ Language = python ]
{
import math, re
try:
    from collections import Counter
except Exception:
    Counter = dict

def tokenize(s):
    s = (s or "").lower()
    s = re.sub(r"[^a-z0-9_]+"," ",s)
    toks = [t for t in s.split() if len(t)>2]
    return toks

# Build corpus: fingerprint -> text
items=[]
for i in range(rows.Size()):
    r = rows.Get(i+1)
    fp = str(r.Get("fingerprint") or "")
    msg = str(r.Get("message") or "")
    if fp:
        items.append((fp, msg))

# If target fp not found, just return top by occurrences already in rows
target_text = None
for fp, msg in items:
    if fp == targetFp:
        target_text = msg
        break
if not target_text:
    out = []
    for fp, msg in items[:5]:
        out.append({"fingerprint": fp, "score": 0.0, "message": msg})
    return out

# TF
docs = {fp: tokenize(msg) for fp, msg in items}
# DF
df={}
for fp, toks in docs.items():
    seen=set(toks)
    for t in seen:
        df[t]=df.get(t,0)+1

N=len(docs) or 1
def tfidf_vec(toks):
    tf={}
    for t in toks:
        tf[t]=tf.get(t,0)+1
    vec={}
    for t,c in tf.items():
        idf = math.log((N+1)/(df.get(t,1)+1))+1.0
        vec[t]=c*idf
    return vec

def cosine(a,b):
    dot=0.0
    na=0.0
    nb=0.0
    for k,v in a.items():
        na += v*v
        if k in b:
            dot += v*b[k]
    for v in b.values():
        nb += v*v
    if na<=0 or nb<=0:
        return 0.0
    return dot / (math.sqrt(na)*math.sqrt(nb))

target_vec = tfidf_vec(docs.get(targetFp, []))
scores=[]
for fp, toks in docs.items():
    if fp==targetFp: 
        continue
    sc = cosine(target_vec, tfidf_vec(toks))
    scores.append((sc, fp))

scores.sort(reverse=True)
out=[]
for sc, fp in scores[:5]:
    msg = next((m for f,m in items if f==fp), "")
    out.append({"fingerprint": fp, "score": float(round(sc,4)), "message": msg})
return out
}

ClassMethod FlakyScore(statusHistory As %DynamicArray) As %Numeric [ Language = python ]
{
# statusHistory: array of objects {status: 'passed'/'failed'} in DESC order
hist=[]
for i in range(statusHistory.Size()):
    s = statusHistory.Get(i+1).Get("status")
    hist.append(str(s))
if len(hist) < 3:
    return 0
# transitions between pass/fail in recent history
trans=0
for i in range(1,len(hist)):
    if hist[i]!=hist[i-1]:
        trans += 1
# normalize
score = (trans / (len(hist)-1)) * 100.0
return round(score, 1)
}

}
