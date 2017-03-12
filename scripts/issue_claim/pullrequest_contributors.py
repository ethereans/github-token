import sys
import json
import urllib
from collections import defaultdict

auth = "?client_id=&client_secret="


repo = sys.argv[1]
pr = sys.argv[2]
link_pulls_commits = "https://api.github.com/repos/" + repo + "/pulls/" + pr + "/commits" +auth
points = defaultdict(int)
commits = json.load(urllib.urlopen(link_pulls_commits))
for commit in commits:
    if(commit['url']):
        link_commit = json.dumps(commit['url'])[1:-1] +auth
        _commit = json.load(urllib.urlopen(link_commit))
        author = json.dumps(_commit['author']['login'])[1:-1]
        points[author] += int(json.dumps(_commit['stats']['total']))
print points.items()