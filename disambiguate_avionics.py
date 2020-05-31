import os
import sys
import json
import tfidf_matcher as tm

cases = json.loads(sys.argv[1])
with open("diverse_avionics_candidate_names.json") as f:
    avionics_dataset = json.loads(f.read())

outkeys = []
outvals = []
for avionic_key, variations in avionics_dataset:
    variation_set = [e for e in variations if e and e.replace(" ", "") and len(e) > 3]
    variation_set.append(avionic_key[0])
    variation_set.append(avionic_key[1])
    variation_set.append(avionic_key[2])
    for var in variation_set:
        outkeys.append(avionic_key)
        outvals.append(var)

resolutions = tm.matcher(cases, outvals, 1, 2).to_numpy().tolist()
results = {}
for resolution in resolutions:
    results[resolution[1]] = {"resolved_case": outkeys[outvals.index(resolution[-1])], "output": resolution}

print(json.dumps(results))