import json
import re
import sys

import yaml

yaml_file = sys.argv[1]
json_file = re.sub('\.yaml$', '.json', yaml_file)

with open(yaml_file, 'r') as stream:
	yaml_content = yaml.load(stream)

with open(json_file, 'w') as outfile:
	json.dump(yaml_content, outfile, sort_keys=True, indent=2)
