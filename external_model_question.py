import pickle
import sys
import json
model_filename = sys.argv[1]
observation = json.loads(open(sys.argv[2]).read())
print(json.dumps(pickle.loads(open(model_filename).read()).predict(observation).tolist()))